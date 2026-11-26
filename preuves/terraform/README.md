# Vitrine Terraform

**Date :** 2026-11-26
**Code :** [`infra/terraform`](../../infra/terraform/) · Terraform 1.17.2, azurerm 5.15.0, azapi 2.14.0

## Vérifications statiques, à chaque PR

Le job requis `Terraform (fmt, validate, tflint)` de la CI ([premier passage, PR #16](https://github.com/Stephane-Dedu/eval-quiz-app/pull/16)) :
- vérifie le formatage, la validité du code et les règles tflint, générales et propres à Azure ;
- est complété par le scan Trivy en mode configuration (0 mauvaise configuration).

## Plan réel contre l'abonnement

`terraform plan` s'authentifie auprès d'Azure, lit l'état réel de l'abonnement et calcule ce qu'il créerait, **sans rien créer**. Exécuté avec les applications (`deploy_apps=true`) et l'image en production :

```console
$ terraform plan -var deploy_apps=true -var image_tag=df88c2cab964e4392f0288588ff8b0516dd52a65
# azapi_resource.environment will be created
# azurerm_consumption_budget_resource_group.quiz will be created
# azurerm_container_app.backend[0] will be created
# azurerm_container_app.frontend[0] will be created
# azurerm_container_registry.quiz will be created
# azurerm_federated_identity_credential.github will be created
# azurerm_log_analytics_workspace.quiz will be created
# azurerm_resource_group.quiz will be created
# azurerm_role_assignment.ci_acr will be created
# azurerm_role_assignment.ci_container_apps will be created
# azurerm_role_assignment.ci_pull_identity will be created
# azurerm_role_assignment.pull_acr will be created
# azurerm_user_assigned_identity.ci will be created
# azurerm_user_assigned_identity.pull will be created

Plan: 14 to add, 0 to change, 0 to destroy.
```

Extrait limité à la liste des ressources : aucun attribut n'est reproduit ici. Dans la sortie complète, les 13 valeurs issues de variables sensibles (mots de passe, secret JWT, URL de la base) apparaissent comme `(sensitive value)`, et la clé du workspace comme `(write-only attribute)`.

Les 14 ressources correspondent une à une à celles de `deploy.sh` ([table de correspondance](../../infra/terraform/README.md#correspondance-avec-deploysh)).

## `apply` et `destroy` : après la soutenance

Azure for Students n'autorise qu'**un environnement Container Apps par abonnement**. Exécuter `apply` imposerait de détruire d'abord le déploiement évalué, puis d'attendre plusieurs dizaines de minutes que la région se libère avant de le recréer ([ADR 0005](../../docs/adr/0005-environnement-workload-profiles.md)). L'`apply` réel est donc prévu après la soutenance, avec l'accord du formateur, au moment où le sujet demande de supprimer les ressources.
