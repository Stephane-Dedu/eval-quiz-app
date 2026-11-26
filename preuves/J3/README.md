# J3 — Ressources Azure créées avec Azure CLI

**Date :** 2026-11-26
**Script :** [`scripts/deploy.sh`](../../scripts/deploy.sh) (Azure CLI 2.93), supprimées par [`scripts/destroy.sh`](../../scripts/destroy.sh)

Toutes les ressources sont créées par `deploy.sh`, sans manipulation dans le portail. Le détail des choix est dans [`docs/technique/azure.md`](../../docs/technique/azure.md).

## Ressources

```console
$ az resource list -g rg-quiz-gwc --query '[].{nom:name, ressource:type, region:location}' -o table
Nom               Ressource                                         Region
----------------  ------------------------------------------------  ------------------
ca-quiz-backend   Microsoft.App/containerApps                       belgiumcentral
ca-quiz-frontend  Microsoft.App/containerApps                       belgiumcentral
cae-quiz          Microsoft.App/managedEnvironments                 belgiumcentral
crquizsdedu       Microsoft.ContainerRegistry/registries            germanywestcentral
id-quiz-pull      Microsoft.ManagedIdentity/userAssignedIdentities  germanywestcentral
id-quiz-github    Microsoft.ManagedIdentity/userAssignedIdentities  germanywestcentral
log-quiz          Microsoft.OperationalInsights/workspaces          germanywestcentral

$ az acr show -n crquizsdedu --query '{sku:sku.name, adminUserEnabled:adminUserEnabled, loginServer:loginServer}'
{
  "adminUserEnabled": false,
  "loginServer": "crquizsdedu.azurecr.io",
  "sku": "Basic"
}

$ az role assignment list --scope <groupe, registre, identité> → rôles des identités
id-quiz-pull	AcrPull	rg-quiz-gwc/Microsoft.ContainerRegistry/registries/crquizsdedu
id-quiz-github	AcrPush	rg-quiz-gwc/Microsoft.ContainerRegistry/registries/crquizsdedu
id-quiz-github	Container Apps Contributor	rg-quiz-gwc
id-quiz-github	Managed Identity Operator	rg-quiz-gwc/Microsoft.ManagedIdentity/userAssignedIdentities/id-quiz-pull

$ az consumption budget (API) → budget-quiz
{
  "montant": 10.0,
  "periode": "Monthly",
  "seuils": [
    50.0,
    80.0,
    100.0
  ]
}
```

- **Deux régions.** Le registre, les identités et les journaux sont en `germanywestcentral`. L'environnement Container Apps et les deux applications sont en `belgiumcentral`. Azure for Students n'autorise qu'un environnement par abonnement, et `germanywestcentral` est restée bloquée après la suppression d'un premier environnement en mode Express ([ADR 0005](../../docs/adr/0005-environnement-workload-profiles.md)).
- **Registre sans compte administrateur** (`adminUserEnabled: false`). Les applications tirent les images avec l'identité `id-quiz-pull` (rôle `AcrPull`). Le CD publie avec `id-quiz-github` (rôle `AcrPush`), par OIDC.

## Images taguées par le commit

Chaque image porte le SHA complet du commit qui l'a produite, du plus récent au plus ancien :

```console
$ az acr repository show-tags -n crquizsdedu --repository quiz-backend --orderby time_desc
df88c2cab964e4392f0288588ff8b0516dd52a65
1d38574f52cd9a7f316ba4fb6e08f1bb9b336de2
05780a476cbbe32748d63ca3ca59cc14ee104388
3f5ab0d0e960081f74ca10d4b113621699b6223b
4eaf1123785bfb715c2e21cd91250f126ce4501c
$ az acr repository show-tags -n crquizsdedu --repository quiz-frontend --orderby time_desc
df88c2cab964e4392f0288588ff8b0516dd52a65
1d38574f52cd9a7f316ba4fb6e08f1bb9b336de2
05780a476cbbe32748d63ca3ca59cc14ee104388
3f5ab0d0e960081f74ca10d4b113621699b6223b
4eaf1123785bfb715c2e21cd91250f126ce4501c
```

| Tag | Origine |
| --- | --- |
| `4eaf112…` | Premier déploiement par `deploy.sh` |
| `3f5ab0d…` | CD, fusion de la [PR #11](https://github.com/Stephane-Dedu/eval-quiz-app/pull/11) |
| `05780a4…` | CD, fusion de la [PR #12](https://github.com/Stephane-Dedu/eval-quiz-app/pull/12) |
| `1d38574…` | CD, fusion de la [PR #13](https://github.com/Stephane-Dedu/eval-quiz-app/pull/13) (Question modifiée) |
| `df88c2c…` | CD, fusion de la [PR #14](https://github.com/Stephane-Dedu/eval-quiz-app/pull/14), en production |

## Un second passage ne change rien, et ne revient jamais en arrière

`deploy.sh` est rejouable : chaque ressource existante est laissée telle quelle ou remise dans l'état décrit. Une application existante **garde son image** : seul le CD la fait évoluer ([ADR 0004](../../docs/adr/0004-cd-sans-secret-applicatif.md)). Passage après un déploiement du CD, depuis un poste dont le dépôt local a des modifications non commitées :

```console
== Avant (HEAD local : df88c2c, arbre modifié)
ca-quiz-backend : ca-quiz-backend--0000006
quiz-backend:df88c2cab964e4392f0288588ff8b0516dd52a65
ca-quiz-frontend : ca-quiz-frontend--0000006
quiz-frontend:df88c2cab964e4392f0288588ff8b0516dd52a65

$ ./scripts/deploy.sh
Déploiement de Quiz App
  abonnement   : Azure for Students
  région       : germanywestcentral (environnement Container Apps : belgiumcentral)
  groupe       : rg-quiz-gwc
  tag d'image  : df88c2cab964e4392f0288588ff8b0516dd52a65 (utilisé seulement pour créer une application)
▶ Fournisseurs de ressources
  Microsoft.App : enregistré
  Microsoft.ContainerRegistry : enregistré
  Microsoft.OperationalInsights : enregistré
  Microsoft.ManagedIdentity : enregistré
▶ Groupe de ressources
  rg-quiz-gwc
▶ Alerte budgétaire
  budget-quiz : déjà en place
▶ Espace Log Analytics
  log-quiz (rétention 30 jours)
▶ Azure Container Registry
  crquizsdedu.azurecr.io (SKU Basic, compte administrateur désactivé)
▶ Identités managées
  id-quiz-pull
  id-quiz-github
▶ Droits
  AcrPull sur crquizsdedu : déjà attribué
  AcrPush sur crquizsdedu : déjà attribué
  Container Apps Contributor sur rg-quiz-gwc : déjà attribué
  Managed Identity Operator sur id-quiz-pull : déjà attribué
▶ Identifiant fédéré GitHub (OIDC)
  sujet accepté : repo:Stephane-Dedu@105072484/eval-quiz-app@1472861267:environment:production
▶ Environnement Container Apps
  cae-quiz (mode WorkloadProfiles, trafic entre applications chiffré, blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io)
▶ Schéma PostgreSQL
  tables déjà présentes : init.sql n'est pas rejoué
▶ Images
  quiz-backend : application existante, image inchangée (crquizsdedu.azurecr.io/quiz-backend:df88c2cab964e4392f0288588ff8b0516dd52a65)
  quiz-frontend : application existante, image inchangée (crquizsdedu.azurecr.io/quiz-frontend:df88c2cab964e4392f0288588ff8b0516dd52a65)
▶ Application backend
▶ Application frontend
▶ Vérification
  GET https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/health → 200
  ca-quiz-backend : révision ca-quiz-backend--0000006
  ca-quiz-frontend : révision ca-quiz-frontend--0000006
✅ Déploiement terminé
  Application     : https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io
  Administration  : https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/gestion-quiz
  Image backend   : crquizsdedu.azurecr.io/quiz-backend:df88c2cab964e4392f0288588ff8b0516dd52a65
  Image frontend  : crquizsdedu.azurecr.io/quiz-frontend:df88c2cab964e4392f0288588ff8b0516dd52a65

== Après
ca-quiz-backend : ca-quiz-backend--0000006
quiz-backend:df88c2cab964e4392f0288588ff8b0516dd52a65
ca-quiz-frontend : ca-quiz-frontend--0000006
quiz-frontend:df88c2cab964e4392f0288588ff8b0516dd52a65
```

Aucune image construite, aucune image remplacée, aucune révision créée.

**Pourquoi cette règle.** Dans sa première version, `deploy.sh` passait `--image <tag>` à chaque mise à jour. Relancé après un déploiement du CD, il a ramené la production à une image plus ancienne : c'est la révision `--0000002` de l'[historique](../J4/README.md#révisions), à 12:48, corrigée à la main à 12:52 (`--0000003`). Désormais, le tag d'image ne sert qu'à créer une application.

## Destruction

`./scripts/destroy.sh` liste les ressources du groupe, demande de retaper son nom, supprime le budget puis le groupe entier. Le cycle complet `destroy.sh` puis `deploy.sh` est réservé à la fin du projet, comme le demande le sujet. Après la suppression d'un environnement, Azure for Students bloque la création d'un nouvel environnement pendant plusieurs dizaines de minutes : l'application serait indisponible tout ce temps.
