#!/usr/bin/env bash
# Supprime toutes les ressources Azure créées par deploy.sh.
#
# Tout vit dans un seul groupe de ressources : le supprimer supprime le
# registre et ses images, les applications, l'environnement, les journaux, les
# identités (donc l'accès OIDC de GitHub) et leurs attributions de rôles.
#
# Usage : ./scripts/destroy.sh [--yes]
#         Sans --yes, le nom du groupe doit être retapé pour confirmer.
#
# À ne lancer qu'après avoir sauvegardé les preuves et obtenu l'accord du
# formateur (README du sujet).

set -euo pipefail
export PYTHONWARNINGS=ignore

RESOURCE_GROUP=${RESOURCE_GROUP:-rg-quiz-gwc}

die() { printf '✗ %s\n' "$*" >&2; exit 1; }

command -v az >/dev/null || die "az est requis"
az account show >/dev/null 2>&1 || die "Azure CLI n'est pas connecté : az login"

if [[ $(az group exists -n "$RESOURCE_GROUP") != true ]]; then
  echo "Le groupe $RESOURCE_GROUP n'existe pas : rien à supprimer."
  exit 0
fi

echo "Ressources du groupe $RESOURCE_GROUP :"
az resource list -g "$RESOURCE_GROUP" --query "[].{nom:name, ressource:type}" -o table

if [[ ${1:-} != --yes ]]; then
  read -r -p $'\nRetapez le nom du groupe pour tout supprimer : ' answer
  [[ $answer == "$RESOURCE_GROUP" ]] || die "Confirmation incorrecte : rien n'a été supprimé."
fi

# Le budget est rattaché au groupe mais n'apparaît pas dans sa liste de ressources.
subscription_id=$(az account show --query id -o tsv)
az rest --method delete \
  --url "https://management.azure.com/subscriptions/$subscription_id/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Consumption/budgets/budget-quiz?api-version=2023-05-01" \
  >/dev/null 2>&1 || true

echo "Suppression de $RESOURCE_GROUP (quelques minutes)…"
az group delete -n "$RESOURCE_GROUP" --yes
echo "✅ $RESOURCE_GROUP supprimé."
