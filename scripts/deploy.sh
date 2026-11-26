#!/usr/bin/env bash
# Déploie Quiz App sur Azure Container Apps avec Azure CLI.
#
# Rejouable : chaque ressource est créée si elle manque, sinon remise dans
# l'état décrit ici. Une seconde exécution sans changement ne recrée rien et
# ne produit pas de nouvelle révision.
#
# Usage :
#   export ADMIN_PASSWORD='…' JWT_SECRET="$(openssl rand -hex 32)"
#   export DATABASE_URL='postgresql://…?sslmode=verify-full'   # facultatif (J4 sans base)
#   ./scripts/deploy.sh
#
# Obligatoires : ADMIN_PASSWORD (12 caractères min.), JWT_SECRET (32 min.)
# Facultatives :
#   DATABASE_URL    PostgreSQL externe (Neon), TLS obligatoire. Absente : le
#                   backend démarre sans base (il ne s'y connecte qu'à la
#                   première requête) et le schéma n'est pas initialisé.
#   RESEND_API_KEY  Absente : clé factice, les emails ne partent pas.
#   ADMIN_USERNAME (admin), FROM_EMAIL, MIN_REPLICAS (0), MAX_REPLICAS (3),
#   IMAGE_TAG (SHA du commit courant), BUDGET_AMOUNT (10), BUDGET_EMAIL
#   (compte az), et les noms de ressources de la section « Configuration ».
#
# Requiert : az (connecté), docker avec buildx, git, jq, openssl ;
#            trivy pour scanner les images avant publication.
#
# Les secrets ne sont jamais écrits dans le dépôt ni affichés : ils passent de
# l'environnement de l'opérateur aux secrets Container Apps.

set -euo pipefail
export PYTHONWARNINGS=ignore # az sous Python 3.14 affiche un SyntaxWarning à chaque appel

cd "$(dirname "$0")/.."

# --- Configuration ------------------------------------------------------------

LOCATION=${LOCATION:-germanywestcentral}
# Région de l'environnement Container Apps (et donc des applications). Azure for
# Students n'autorise qu'un environnement par région, et une région reste bloquée
# un temps indéterminé après la suppression de son environnement (ADR 0005).
ENVIRONMENT_LOCATION=${ENVIRONMENT_LOCATION:-belgiumcentral}
RESOURCE_GROUP=${RESOURCE_GROUP:-rg-quiz-gwc}
ACR_NAME=${ACR_NAME:-crquizsdedu}
LOG_WORKSPACE=${LOG_WORKSPACE:-log-quiz}
ENVIRONMENT=${ENVIRONMENT:-cae-quiz}
FRONTEND_APP=${FRONTEND_APP:-ca-quiz-frontend}
BACKEND_APP=${BACKEND_APP:-ca-quiz-backend}
PULL_IDENTITY=${PULL_IDENTITY:-id-quiz-pull}
CI_IDENTITY=${CI_IDENTITY:-id-quiz-github}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-Stephane-Dedu/eval-quiz-app}
GITHUB_ENVIRONMENT=${GITHUB_ENVIRONMENT:-production}
# Préfixe du sujet des jetons OIDC de ce dépôt, identifiants immuables compris :
#   gh api repos/<compte>/<dépôt>/actions/oidc/customization/sub --jq .sub_claim_prefix
GITHUB_OIDC_SUBJECT_PREFIX=${GITHUB_OIDC_SUBJECT_PREFIX:-repo:Stephane-Dedu@105072484/eval-quiz-app@1472861267}
MIN_REPLICAS=${MIN_REPLICAS:-0}
MAX_REPLICAS=${MAX_REPLICAS:-3}
HTTP_CONCURRENCY=${HTTP_CONCURRENCY:-20}
BUDGET_AMOUNT=${BUDGET_AMOUNT:-10}
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
RESEND_API_KEY=${RESEND_API_KEY:-re_factice_emails_desactives}
FROM_EMAIL=${FROM_EMAIL:-}
BUILDER=quiz-deploy
# Client psql pour initialiser le schéma : même version que la base locale.
PSQL_IMAGE=postgres:18.7-alpine3.24@sha256:0115267ab5a509022df9319c77be365cef335adb71556c75f60f5360ee247e71

TAGS=(projet=quiz-app gestion=deploy.sh)

# --- Affichage ----------------------------------------------------------------

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  ⚠ %s\n' "$*" >&2; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

# --- Vérifications préalables -------------------------------------------------

for cmd in az docker git jq openssl; do
  command -v "$cmd" >/dev/null || die "$cmd est requis"
done
az account show >/dev/null 2>&1 || die "Azure CLI n'est pas connecté : az login"

: "${ADMIN_PASSWORD:?ADMIN_PASSWORD est requis}"
: "${JWT_SECRET:?JWT_SECRET est requis (openssl rand -hex 32)}"
((${#ADMIN_PASSWORD} >= 12)) || die "ADMIN_PASSWORD : 12 caractères minimum"
((${#JWT_SECRET} >= 32)) || die "JWT_SECRET : 32 caractères minimum"
case "$ADMIN_PASSWORD" in admin123 | changeme) die "ADMIN_PASSWORD : valeur par défaut interdite" ;; esac
case "$JWT_SECRET" in change-this-secret | change-this-to-a-secure-random-string)
  die "JWT_SECRET : valeur par défaut interdite" ;;
esac
if [[ -n ${DATABASE_URL:-} && $DATABASE_URL != *sslmode=verify-full* && $DATABASE_URL != *sslmode=require* ]]; then
  die "DATABASE_URL doit imposer TLS (sslmode=verify-full)"
fi

# Le tag d'image est le SHA du commit : il n'a de sens que si le code
# construit est exactement ce commit.
if [[ -z ${IMAGE_TAG:-} ]]; then
  [[ -z $(git status --porcelain) ]] \
    || die "Modifications non commitées : l'image ne correspondrait à aucun commit. Committez, ou fixez IMAGE_TAG."
  IMAGE_TAG=$(git rev-parse HEAD)
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
BUDGET_EMAIL=${BUDGET_EMAIL:-$(az account show --query user.name -o tsv)}

echo "Déploiement de Quiz App"
info "abonnement   : $(az account show --query name -o tsv)"
info "région       : $LOCATION (environnement Container Apps : $ENVIRONMENT_LOCATION)"
info "groupe       : $RESOURCE_GROUP"
info "tag d'image  : $IMAGE_TAG"

# --- Fonctions utilitaires ----------------------------------------------------

# exists COMMANDE… : vrai si la commande « show » trouve la ressource.
exists() { "$@" >/dev/null 2>&1; }

# ensure_role PRINCIPAL RÔLE PORTÉE : attribue le rôle s'il ne l'est pas déjà.
ensure_role() {
  local principal=$1 role=$2 scope=$3 count
  count=$(az role assignment list --scope "$scope" --role "$role" \
    --query "length([?principalId=='$principal'])" -o tsv)
  if [[ $count == 0 ]]; then
    az role assignment create --assignee-object-id "$principal" \
      --assignee-principal-type ServicePrincipal --role "$role" --scope "$scope" -o none
    info "$role sur ${scope##*/} : attribué"
  else
    info "$role sur ${scope##*/} : déjà attribué"
  fi
}

# --- 1. Fournisseurs de ressources --------------------------------------------

step "Fournisseurs de ressources"
for provider in Microsoft.App Microsoft.ContainerRegistry Microsoft.OperationalInsights Microsoft.ManagedIdentity; do
  if [[ $(az provider show -n "$provider" --query registrationState -o tsv) != Registered ]]; then
    info "$provider : enregistrement…"
    az provider register -n "$provider" --wait
  fi
  info "$provider : enregistré"
done

# --- 2. Groupe de ressources et budget ----------------------------------------

step "Groupe de ressources"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --tags "${TAGS[@]}" -o none
info "$RESOURCE_GROUP"

step "Alerte budgétaire"
budget_url="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Consumption/budgets/budget-quiz?api-version=2023-05-01"
if exists az rest --method get --url "$budget_url"; then
  info "budget-quiz : déjà en place"
else
  budget_body=$(jq -n --argjson amount "$BUDGET_AMOUNT" --arg email "$BUDGET_EMAIL" \
    --arg start "$(date -u +%Y-%m-01T00:00:00Z)" '
    def alert($pct): {enabled: true, operator: "GreaterThanOrEqualTo", threshold: $pct,
                      thresholdType: "Actual", contactEmails: [$email]};
    {properties: {category: "Cost", amount: $amount, timeGrain: "Monthly",
                  timePeriod: {startDate: $start},
                  notifications: {seuil50: alert(50), seuil80: alert(80), seuil100: alert(100)}}}')
  if az rest --method put --url "$budget_url" --body "$budget_body" -o none; then
    info "budget-quiz : $BUDGET_AMOUNT par mois, alertes à 50, 80 et 100 % vers $BUDGET_EMAIL"
  else
    warn "budget non créé (type d'abonnement non pris en charge ?) ; le déploiement continue"
  fi
fi

# --- 3. Journaux --------------------------------------------------------------

step "Espace Log Analytics"
exists az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" \
  || az monitor log-analytics workspace create -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" \
    -l "$LOCATION" --retention-time 30 --tags "${TAGS[@]}" -o none
LOG_CUSTOMER_ID=$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query customerId -o tsv)
info "$LOG_WORKSPACE (rétention 30 jours)"

# --- 4. Registre --------------------------------------------------------------

step "Azure Container Registry"
exists az acr show -g "$RESOURCE_GROUP" -n "$ACR_NAME" \
  || az acr create -g "$RESOURCE_GROUP" -n "$ACR_NAME" -l "$LOCATION" --sku Basic \
    --admin-enabled false --tags "${TAGS[@]}" -o none
# Pas de compte administrateur partagé : l'accès passe par des identités et des rôles.
az acr update -n "$ACR_NAME" --admin-enabled false -o none
ACR_ID=$(az acr show -n "$ACR_NAME" --query id -o tsv)
ACR_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)
info "$ACR_SERVER (SKU Basic, compte administrateur désactivé)"

# --- 5. Identités et droits ---------------------------------------------------

step "Identités managées"
for identity in "$PULL_IDENTITY" "$CI_IDENTITY"; do
  exists az identity show -g "$RESOURCE_GROUP" -n "$identity" \
    || az identity create -g "$RESOURCE_GROUP" -n "$identity" -l "$LOCATION" --tags "${TAGS[@]}" -o none
  info "$identity"
done
PULL_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$PULL_IDENTITY" --query id -o tsv)
PULL_PRINCIPAL=$(az identity show -g "$RESOURCE_GROUP" -n "$PULL_IDENTITY" --query principalId -o tsv)
CI_PRINCIPAL=$(az identity show -g "$RESOURCE_GROUP" -n "$CI_IDENTITY" --query principalId -o tsv)
CI_CLIENT_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$CI_IDENTITY" --query clientId -o tsv)
RG_ID=$(az group show -n "$RESOURCE_GROUP" --query id -o tsv)

step "Droits"
# Les applications tirent les images avec une identité qui ne peut que lire le registre.
ensure_role "$PULL_PRINCIPAL" AcrPull "$ACR_ID"
# Le CD peut publier des images et mettre à jour les applications, rien d'autre :
# ni lire les secrets d'une autre ressource, ni créer de ressource hors Container Apps.
ensure_role "$CI_PRINCIPAL" AcrPush "$ACR_ID"
ensure_role "$CI_PRINCIPAL" "Container Apps Contributor" "$RG_ID"
# Mettre à jour une application qui utilise l'identité de tirage exige le droit
# de l'« assigner », même sans la changer.
ensure_role "$CI_PRINCIPAL" "Managed Identity Operator" "$PULL_ID"

step "Identifiant fédéré GitHub (OIDC)"
# GitHub signe ses jetons avec un sujet fondé sur les identifiants immuables du
# compte et du dépôt (repo:<compte>@<id>/<dépôt>@<id>:…). Un dépôt renommé, ou
# supprimé puis recréé sous le même nom, n'obtient donc pas cette confiance.
federated=github-$GITHUB_ENVIRONMENT
subject="$GITHUB_OIDC_SUBJECT_PREFIX:environment:$GITHUB_ENVIRONMENT"
current=$(az identity federated-credential show -g "$RESOURCE_GROUP" --identity-name "$CI_IDENTITY" -n "$federated" \
  --query subject -o tsv 2>/dev/null || true)
if [[ -z $current ]]; then
  az identity federated-credential create -g "$RESOURCE_GROUP" --identity-name "$CI_IDENTITY" -n "$federated" \
    --issuer https://token.actions.githubusercontent.com --subject "$subject" \
    --audiences api://AzureADTokenExchange -o none
elif [[ $current != "$subject" ]]; then
  az identity federated-credential update -g "$RESOURCE_GROUP" --identity-name "$CI_IDENTITY" -n "$federated" \
    --issuer https://token.actions.githubusercontent.com --subject "$subject" \
    --audiences api://AzureADTokenExchange -o none
fi
info "sujet accepté : $subject"

# --- 6. Environnement Container Apps ------------------------------------------

step "Environnement Container Apps"
# Créé par l'API REST, pas par « az containerapp env create » : Azure CLI ne
# sait pas choisir le mode d'environnement et crée un environnement « Express ».
# Ce mode n'a ni découverte de services interne (le frontend ne pourrait pas
# joindre un backend interne) ni domaine personnalisé. Le mode WorkloadProfiles
# les a, ainsi que le chiffrement du trafic entre applications.
env_api="https://management.azure.com$RG_ID/providers/Microsoft.App/managedEnvironments/$ENVIRONMENT?api-version=2026-07-01"
env_mode=$(az rest --method get --url "$env_api" --query properties.environmentMode -o tsv 2>/dev/null || true)
if [[ -z $env_mode ]]; then
  LOG_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" \
    --query primarySharedKey -o tsv)
  env_body=$(jq -n --arg location "$ENVIRONMENT_LOCATION" --arg id "$LOG_CUSTOMER_ID" --arg key "$LOG_KEY" '{
    location: $location,
    tags: {projet: "quiz-app", gestion: "deploy.sh"},
    properties: {
      environmentMode: "WorkloadProfiles",
      workloadProfiles: [{name: "Consumption", workloadProfileType: "Consumption"}],
      peerTrafficConfiguration: {encryption: {enabled: true}},
      appLogsConfiguration: {destination: "log-analytics",
                             logAnalyticsConfiguration: {customerId: $id, sharedKey: $key}}}}')
  az rest --method put --url "$env_api" --body "$env_body" -o none
  # La création est asynchrone : on attend qu'elle aboutisse.
  for _ in $(seq 1 60); do
    state=$(az rest --method get --url "$env_api" --query properties.provisioningState -o tsv)
    [[ $state == Succeeded ]] && break
    [[ $state == Failed ]] && die "création de $ENVIRONMENT en échec"
    sleep 10
  done
  [[ $state == Succeeded ]] || die "création de $ENVIRONMENT trop longue"
elif [[ $env_mode != WorkloadProfiles ]]; then
  die "$ENVIRONMENT est en mode $env_mode : il faut le mode WorkloadProfiles. Supprimez-le (az containerapp env delete) puis relancez."
fi
info "$ENVIRONMENT (mode WorkloadProfiles, trafic entre applications chiffré, $(az containerapp env show -g "$RESOURCE_GROUP" -n "$ENVIRONMENT" --query properties.defaultDomain -o tsv))"

# --- 7. Schéma de la base -----------------------------------------------------

if [[ -n ${DATABASE_URL:-} ]]; then
  step "Schéma PostgreSQL"
  # psql lit les certificats racine du système avec sslrootcert=system ; le
  # pilote Node du backend, lui, utilise ceux de Node et n'a pas besoin du paramètre.
  PSQL_URL=$DATABASE_URL
  [[ $PSQL_URL == *sslmode=verify-full* && $PSQL_URL != *sslrootcert=* ]] && PSQL_URL="$PSQL_URL&sslrootcert=system"
  psql_run() {
    PSQL_URL=$PSQL_URL docker run --rm -i -e PSQL_URL "$PSQL_IMAGE" \
      sh -c 'psql "$PSQL_URL" -X -q -v ON_ERROR_STOP=1 "$@"' psql "$@"
  }
  # init.sql n'est pas rejouable : on ne l'applique que si les tables manquent.
  if [[ $(psql_run -tAc "SELECT to_regclass('public.users') IS NOT NULL") == t ]]; then
    info "tables déjà présentes : init.sql n'est pas rejoué"
  else
    psql_run <database/init.sql
    info "init.sql appliqué"
  fi
else
  step "Schéma PostgreSQL"
  warn "DATABASE_URL absente : backend déployé sans base (suffisant pour J4)"
fi

# --- 8. Images ----------------------------------------------------------------

step "Images ($IMAGE_TAG)"
# Constructeur BuildKit dédié : contrairement au pilote « docker » par défaut,
# il sait attacher SBOM et provenance aux images publiées.
exists docker buildx inspect "$BUILDER" || docker buildx create --name "$BUILDER" --driver docker-container >/dev/null
logged_in=false

publish() {
  local name=$1 context=$2 ref
  ref="$ACR_SERVER/quiz-$name:$IMAGE_TAG"
  if exists az acr repository show -n "$ACR_NAME" --image "quiz-$name:$IMAGE_TAG"; then
    info "quiz-$name : déjà publiée (par la CI ou un déploiement précédent)"
    return
  fi
  if [[ $logged_in == false ]]; then
    az acr login -n "$ACR_NAME" >/dev/null
    logged_in=true
  fi
  local build=(docker buildx build --builder "$BUILDER" --platform linux/amd64
    --build-arg "REVISION=$IMAGE_TAG" -t "$ref" --quiet)
  info "quiz-$name : construction linux/amd64…"
  "${build[@]}" --load "$context" >/dev/null
  # Aucune image ne part au registre sans scan : mêmes règles que la CI.
  if command -v trivy >/dev/null; then
    trivy image --quiet --scanners vuln --severity CRITICAL --exit-code 1 "$ref" \
      || die "quiz-$name : vulnérabilité CRITICAL, publication annulée"
    trivy image --quiet --scanners vuln --severity HIGH --ignore-unfixed --exit-code 1 "$ref" \
      || die "quiz-$name : vulnérabilité HIGH corrigeable, publication annulée"
    info "quiz-$name : Trivy OK"
  else
    warn "trivy absent : image publiée sans scan local"
  fi
  # Même build, repris du cache, cette fois publié avec SBOM et provenance.
  "${build[@]}" --sbom=true --provenance=mode=max --push "$context" >/dev/null
  info "quiz-$name : publiée"
}

publish backend backend
publish frontend .

# --- 9. Applications ----------------------------------------------------------

# Empreinte des secrets (pas les secrets) : la changer crée une nouvelle
# révision, qui relit les secrets mis à jour.
SECRETS_VERSION=$(printf '%s\n' "${DATABASE_URL:-}" "$JWT_SECRET" "$ADMIN_PASSWORD" "$RESEND_API_KEY" \
  | openssl dgst -sha256 -r | cut -c1-12)

backend_secrets=(jwt-secret="$JWT_SECRET" admin-password="$ADMIN_PASSWORD" resend-api-key="$RESEND_API_KEY")
backend_env=(JWT_SECRET=secretref:jwt-secret ADMIN_PASSWORD=secretref:admin-password
  RESEND_API_KEY=secretref:resend-api-key ADMIN_USERNAME="$ADMIN_USERNAME" SECRETS_VERSION="$SECRETS_VERSION")
if [[ -n ${DATABASE_URL:-} ]]; then
  backend_secrets+=(database-url="$DATABASE_URL")
  backend_env+=(DATABASE_URL=secretref:database-url)
fi
[[ -n $FROM_EMAIL ]] && backend_env+=(FROM_EMAIL="$FROM_EMAIL")

common=(--cpu 0.25 --memory 0.5Gi --min-replicas "$MIN_REPLICAS" --max-replicas "$MAX_REPLICAS"
  --scale-rule-name http --scale-rule-type http --scale-rule-http-concurrency "$HTTP_CONCURRENCY")

step "Application backend"
if exists az containerapp show -g "$RESOURCE_GROUP" -n "$BACKEND_APP"; then
  az containerapp secret set -g "$RESOURCE_GROUP" -n "$BACKEND_APP" --secrets "${backend_secrets[@]}" -o none
  az containerapp update -g "$RESOURCE_GROUP" -n "$BACKEND_APP" \
    --image "$ACR_SERVER/quiz-backend:$IMAGE_TAG" "${common[@]}" \
    --replace-env-vars "${backend_env[@]}" -o none
else
  # Ingress interne : joignable depuis l'environnement uniquement, pas depuis Internet.
  # Sans sonde déclarée, Container Apps ajoute des sondes TCP sur le port cible :
  # elles n'appellent pas /health, soumis au limiteur de débit.
  az containerapp create -g "$RESOURCE_GROUP" -n "$BACKEND_APP" --environment "$ENVIRONMENT" \
    --image "$ACR_SERVER/quiz-backend:$IMAGE_TAG" \
    --registry-server "$ACR_SERVER" --registry-identity "$PULL_ID" --user-assigned "$PULL_ID" \
    --ingress internal --target-port 3007 --transport http \
    --secrets "${backend_secrets[@]}" --env-vars "${backend_env[@]}" \
    "${common[@]}" --tags "${TAGS[@]}" -o none
fi
info "$BACKEND_APP : http://$BACKEND_APP (interne à l'environnement)"

step "Application frontend"
# Nginx appelle le backend par son nom d'application : la découverte de services
# de l'environnement le résout, et le chiffrement entre applications protège ce
# trafic sans certificat à gérer dans Nginx.
# Tout le trafic entrant passe par le proxy de la plateforme : Nginx peut croire
# la dernière adresse qu'il ajoute à X-Forwarded-For (adresse réelle du client).
frontend_env=(BACKEND_ORIGIN="http://$BACKEND_APP" TRUSTED_PROXY_CIDR=0.0.0.0/0)
if exists az containerapp show -g "$RESOURCE_GROUP" -n "$FRONTEND_APP"; then
  az containerapp update -g "$RESOURCE_GROUP" -n "$FRONTEND_APP" \
    --image "$ACR_SERVER/quiz-frontend:$IMAGE_TAG" "${common[@]}" \
    --replace-env-vars "${frontend_env[@]}" -o none
else
  # Ingress externe en HTTPS ; une requête HTTP est redirigée (allowInsecure=false).
  az containerapp create -g "$RESOURCE_GROUP" -n "$FRONTEND_APP" --environment "$ENVIRONMENT" \
    --image "$ACR_SERVER/quiz-frontend:$IMAGE_TAG" \
    --registry-server "$ACR_SERVER" --registry-identity "$PULL_ID" --user-assigned "$PULL_ID" \
    --ingress external --target-port 8080 --transport auto \
    --env-vars "${frontend_env[@]}" "${common[@]}" --tags "${TAGS[@]}" -o none
fi
FRONTEND_URL="https://$(az containerapp show -g "$RESOURCE_GROUP" -n "$FRONTEND_APP" --query properties.configuration.ingress.fqdn -o tsv)"
info "$FRONTEND_APP : $FRONTEND_URL"

# --- 10. Vérification ---------------------------------------------------------

step "Vérification"
# Avec MIN_REPLICAS=0, la première requête réveille le frontend puis le backend.
status=000
for _ in $(seq 1 30); do
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$FRONTEND_URL/health" || true)
  [[ $status == 200 ]] && break
  sleep 10
done
[[ $status == 200 ]] || die "$FRONTEND_URL/health répond $status"
info "GET $FRONTEND_URL/health → 200"

for app in "$BACKEND_APP" "$FRONTEND_APP"; do
  info "$app : révision $(az containerapp show -g "$RESOURCE_GROUP" -n "$app" --query properties.latestReadyRevisionName -o tsv)"
done

cat <<EOF

✅ Déploiement terminé
  Application     : $FRONTEND_URL
  Administration  : $FRONTEND_URL/gestion-quiz
  Images          : $ACR_SERVER/quiz-{frontend,backend}:$IMAGE_TAG

Variables de l'environnement GitHub « $GITHUB_ENVIRONMENT » (identifiants publics, pas des secrets) :
  AZURE_CLIENT_ID=$CI_CLIENT_ID
  AZURE_TENANT_ID=$TENANT_ID
  AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
EOF
