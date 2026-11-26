# Quiz App — évaluation Conteneurs

Application de quiz sur des sujets DevOps, conteneurisée, sécurisée et déployée sur Azure Container Apps dans le cadre de l'évaluation du cours Conteneurs.

## Vocabulaire

### Application de quiz

**Sujet** :
Ensemble thématique de **Questions** (docker, ansible, cicd…) choisi par le **Participant** avant de commencer.
_À éviter_ : thème, questionnaire, catégorie

**Question** :
Énoncé d'un **Sujet**, proposé avec plusieurs **Choix** dont une seule **Bonne réponse**.

**Choix** :
Une des propositions affichées pour une **Question**.
_À éviter_ : réponse, option

**Bonne réponse** :
Le **Choix** correct d'une **Question**.
_À éviter_ : correction, solution

**Réponse** :
Le **Choix** retenu par le **Participant** pour une **Question**, ou l'absence de choix quand le temps imparti est écoulé.
_À éviter_ : choix (dans ce sens), answer

**Résultat** :
Un passage complet d'un quiz par un **Participant**, avec son score et ses **Réponses**.
_À éviter_ : tentative, session, attempt

**Participant** :
Personne qui passe un quiz, identifiée par son email ; un même **Participant** peut cumuler plusieurs **Résultats**, même s'il s'inscrit plusieurs fois.
_À éviter_ : utilisateur, user, candidat

**Administrateur** :
Personne qui consulte, exporte et purge les **Résultats** depuis la page de gestion.
_À éviter_ : gestionnaire

### Évaluation

**Jalon** :
Étape validée de l'évaluation, de J0 (accès Azure) à J6 (CI/CD), démontrée par des **Preuves**.
_À éviter_ : milestone, étape

**Preuve** :
Élément daté conservé dans le dépôt (capture, log expurgé, rapport de scan, lien de run) qui démontre qu'un **Jalon** est atteint.

**Livrable** :
Élément exigé dans le dépôt au moment de la soutenance (Dockerfiles, Compose, scripts, workflow, documentation).
_À éviter_ : preuve (une **Preuve** justifie un **Jalon**, un **Livrable** est attendu en fin de projet)

**Volet** :
Un des sept blocs de la chaîne de livraison : application, Dockerfile, conteneurs, Compose, CI/CD, déploiement Azure, infrastructure as code ; chaque **Volet** a sa liste de contrôle.
_À éviter_ : couche, layer (réservés aux couches d'une image Docker)
