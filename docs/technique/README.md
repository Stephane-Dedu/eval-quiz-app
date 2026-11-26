# Documentation technique

Documentation du groupe. Les fichiers `docs/01` à `docs/09` sont le sujet du formateur et ne sont pas modifiés.

| Document | Contenu |
| --- | --- |
| [Analyse J1](analyse-j1.md) | Composants, ports, configuration, routes, persistance, architecture locale |
| [Listes de contrôle](checklists.md) | Critères vérifiables pour déclarer chaque **Volet** terminé |
| [Conteneurisation](conteneurisation.md) | Images, Docker Compose, Nginx : lancement local et raisons de chaque choix |
| [CI/CD](ci-cd.md) | Contrôles de PR, protection de `main`, sécurité du dépôt |
| [Décisions d'architecture](../adr/) | Les choix difficiles à défaire et leurs raisons |
| [Vocabulaire](../../GLOSSARY.md) | Les termes du domaine et ceux à éviter |

## Feuille de route

Chaque étape est une PR courte depuis une branche `feature/*` vers `main`, fusionnée en un seul commit.

| # | PR | Volet | Jalon |
| --- | --- | --- | --- |
| 1 | Cadrage : vocabulaire, décisions, listes de contrôle, analyse J1, preuve J0 | — | J0, prérequis J1 |
| 2 | Hygiène : fichiers morts, lockfile backend, mise à jour de Vite | Application | — |
| 3 | Dockerfiles initiaux et leur scan Trivy | Dockerfile | J2 (état initial) |
| 4 | Durcissement des images, scans avant/après | Dockerfile, Conteneurs | J2 |
| 5 | Docker Compose, Nginx durci, test d'intégration | Compose | J1 |
| 6 | Contrôles de PR et protection de `main` | CI/CD | J6-A |
| 7 | `deploy.sh`, `destroy.sh` et déploiement, après validation de J1 par le formateur | Azure | J3, J4, J5 |
| 8 | Déploiement continu et démonstration par modification d'une **Question** | CI/CD | J6-B |
| 9 | Terraform, vérifié en CI et prouvé par un `apply` puis un `destroy` | Infrastructure as code | — |
| 10 | Schémas, documentation finale, README | Tous | Livrables |
| 11 | Bonus : mise à l'échelle automatique, sous-domaine personnalisé | Azure | Bonus |
| 12 | Support de soutenance (6 diapositives) | — | Soutenance |

## Conventions

- **Messages de commit** au format Conventional Commits, en français : `feat(docker): …`, `ci: …`, `docs: …`.
- **Tags d'image** : le SHA complet du commit, jamais `latest` seul.
- **Région Azure** : `germanywestcentral`.
- **Noms Azure** : abréviations du Cloud Adoption Framework (`rg-quiz-gwc`, `crquizsdedu`, `cae-quiz`, `ca-quiz-frontend`, `ca-quiz-backend`, `log-quiz`, `id-quiz-github`) ; la variante Terraform ajoute `-tf`.
- **Secrets** : jamais dans le dépôt, les journaux ou les captures. En local dans `.env` (ignoré par git), sur Azure en secrets Container Apps.
