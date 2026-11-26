# Environnement Container Apps en mode WorkloadProfiles, créé par l'API REST

`az containerapp env create` (Azure CLI 2.93) crée un environnement en mode **Express**, sans option pour en choisir un autre. Ce mode ne convient pas à l'architecture du projet :

- pas de découverte de services interne : le frontend ne peut joindre le backend que par une URL publique, alors que l'ingress du backend est interne ;
- ni domaine personnalisé (bonus du sujet), ni HTTP non chiffré entre applications, ni chiffrement entre applications.

`scripts/deploy.sh` crée donc l'environnement par l'API REST (`az rest`, version `2026-07-01`) avec `environmentMode: WorkloadProfiles` et le chiffrement du trafic entre applications. Il refuse de continuer si l'environnement existant est dans un autre mode. Le frontend appelle le backend par son nom d'application (`http://ca-quiz-backend`), résolu par l'environnement et chiffré entre les deux applications.

## Conséquences

L'abonnement Azure for Students impose des limites constatées pendant la mise en place :

- **Un seul environnement Container Apps pour tout l'abonnement**, toutes régions et tous modes confondus (`MaxNumberOfGlobalEnvironmentsInSubExceeded`). Passer d'Express à WorkloadProfiles a imposé de supprimer l'environnement Express.
- **Une région reste bloquée après la suppression de son environnement.** Pendant plus de 30 minutes après la suppression de l'environnement Express, `germanywestcentral` a refusé toute création (`MaxNumberOfEnvironmentsInSubExceeded`), alors que le compteur de quota affichait 0 sur 1. L'environnement est donc placé en `belgiumcentral` (variable `ENVIRONMENT_LOCATION` de `deploy.sh`). Les autres ressources restent en `germanywestcentral`, et la base Neon de Francfort reste à quelques millisecondes.
- **La vitrine Terraform ne peut pas coexister avec le déploiement évalué.** Elle ne pourra être prouvée (`apply` puis `destroy`) qu'après `scripts/destroy.sh`.
