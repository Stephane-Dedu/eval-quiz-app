# Azure CLI déploie, Terraform est une vitrine prouvée

Le sujet impose Azure CLI (`scripts/deploy.sh`, `scripts/destroy.sh`, jalon J3 « ressources créées avec Azure CLI ») et précise que Terraform n'est pas requis. `scripts/deploy.sh` est donc le seul chemin qui déploie l'environnement évalué. `infra/terraform/` décrit les mêmes ressources dans un groupe de ressources distinct ; il est vérifié à chaque PR et prouvé par un `apply` puis un `destroy` documentés. Les deux outils ne gèrent jamais les mêmes ressources.

## Options écartées

- **Terraform seul, appelé par `deploy.sh`** : contredit la formulation de J3.
- **Les deux outils sur les mêmes ressources** : deux sources de vérité qui se contredisent, avec un état Terraform qui dérive à chaque exécution du script.
