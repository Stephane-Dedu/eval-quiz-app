# J0 — Accès Azure

**Date :** 2026-11-26
**Outil :** Azure CLI 2.93.0

## Abonnement

```console
$ az account show --query "{abonnement:name, etat:state, cloud:environmentName, tenant:tenantDisplayName}"
{
  "abonnement": "Azure for Students",
  "cloud": "AzureCloud",
  "etat": "Enabled",
  "tenant": "Emineo Education"
}
```

Les identifiants d'abonnement et de tenant ne sont volontairement pas affichés.

## Droits et contraintes constatés

| Constat | Commande | Conséquence |
| --- | --- | --- |
| Rôle **Owner** sur l'abonnement | `az role assignment list --assignee <moi> --include-inherited` | Possible d'attribuer des rôles à l'identité de la CI |
| Stratégie « Allowed resource deployment regions » : `francecentral`, `germanywestcentral`, `belgiumcentral`, `austriaeast`, `norwayeast` | `az policy assignment list` | Déploiement en `germanywestcentral`, au plus près de la base Neon de Francfort |
| Fournisseurs `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.OperationalInsights`, `Microsoft.ManagedIdentity` non enregistrés | `az provider show -n <fournisseur>` | `deploy.sh` les enregistre avant toute création |
| Création d'inscriptions d'application interdite dans le tenant | Graph `policies/authorizationPolicy` : `allowedToCreateApps = false` | La CI se connecte par une identité managée affectée par l'utilisateur, avec identifiant fédéré GitHub |
| Aucun groupe de ressources existant | `az group list` | Déploiement depuis zéro |
