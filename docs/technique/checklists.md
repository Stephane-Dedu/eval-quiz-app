# Listes de contrôle par Volet

Un **Volet** est terminé quand chaque ligne de sa liste est cochée. Chaque contrôle doit pouvoir être rejoué par quelqu'un d'autre : la colonne « Vérification » donne la commande ou l'observation qui le prouve.

Les exigences du sujet passent avant les bonnes pratiques ; tout écart volontaire est justifié en une ligne dans la documentation du **Volet**.

## Application

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | Aucune modification de logique métier, hormis la **Question** de démonstration | `git diff upstream/main` sur les fichiers applicatifs : seuls la version de Vite (`package.json`) et `import.meta.dirname` (`vite.config.js`) diffèrent |
| ✅ | Les dépendances s'installent de façon reproductible | `npm ci` réussit à la racine et dans `backend/` (lockfiles versionnés) |
| ✅ | Aucun fichier mort ni doublon | Plus de `database/nginx/`, de `*.svg.old` ni d'image non référencée |
| ✅ | Analyse J1 rédigée | `docs/technique/analyse-j1.md` |
| ✅ | Aucune vulnérabilité connue dans les dépendances | `npm audit` (racine) et `npm audit --omit=dev` (`backend/`) : 0 |

## Dockerfile

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | Images multi-étapes : l'image finale ne contient ni outils de build ni `devDependencies` | Pas de `npm` dans l'image backend, pas de `node` dans l'image frontend |
| ✅ | Images de base épinglées par digest | `grep FROM` : chaque ligne contient `@sha256:` |
| ✅ | Exécution en utilisateur non-root | `docker run --rm <image> id -u` ≠ 0 |
| ✅ | Une modification de code seul réutilise la couche des dépendances | Journal de build : l'étape `npm ci` est `CACHED` |
| ✅ | `.dockerignore` en liste blanche : seuls les fichiers nécessaires entrent dans le contexte | Lecture des trois `.dockerignore` |
| ✅ | hadolint propre | `hadolint Dockerfile backend/Dockerfile database/Dockerfile` sans sortie, ou exception justifiée |
| ✅ | Trivy : 0 CRITICAL, 0 HIGH corrigeable | `trivy image --severity HIGH,CRITICAL --ignore-unfixed` et `--severity CRITICAL` |
| ✅ | Vulnérabilités restantes listées et justifiées | Aucune restante (rapport final dans `preuves/J2/`) ; toute exception future va dans `.trivyignore` avec sa raison |
| ✅ | Taille des images mesurée avant et après durcissement | Tableau dans `preuves/J2/` |
| ✅ | Métadonnées OCI (source, révision) | `docker inspect` affiche les labels `org.opencontainers.image.*` ; la CI renseigne la révision |

## Conteneurs

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | Arrêt propre en moins de 2 secondes | `time docker stop <conteneur>` |
| ✅ | Système de fichiers racine en lecture seule | `read_only: true` et le service reste sain |
| ✅ | Aucune capacité Linux, aucune élévation de privilèges | `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]` |
| ✅ | Journaux sur la sortie standard | `docker compose logs <service>` les affiche |
| ✅ | Ressources limitées | Limites CPU et mémoire déclarées par service |

## Compose

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | Démarrage depuis un clone vierge | `cp .env.example .env && docker compose up -d --wait` : les trois services sont `healthy` |
| ✅ | Ordre de démarrage par contrôles de santé | `depends_on` avec `condition: service_healthy` |
| ✅ | Seul le frontend publie un port | `docker compose ps` : seul `8087` est publié |
| ✅ | Le frontend ne peut pas joindre la base | Connexion à `db:5432` depuis le conteneur frontend refusée (réseaux séparés) |
| ✅ | Les données survivent à la recréation des conteneurs | `down` puis `up` sans `-v` : le **Participant** et le **Résultat** sont toujours là |
| ✅ | Le schéma n'est appliqué qu'à la première création du volume | Journal PostgreSQL au second démarrage : aucune exécution de `init.sql` |
| ✅ | Aucun secret dans le fichier Compose | Toutes les valeurs sensibles viennent de `.env`, ignoré par git |
| ✅ | Test d'intégration au vert | `scripts/smoke-test.sh` |

## CI/CD

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | Chaque PR exécute lint, build, scans Trivy et test d'intégration | Onglet Checks de la PR |
| ✅ | Une vulnérabilité CRITICAL fait échouer le contrôle, sans `continue-on-error` | PR #7 : CVE-2019-10744 rejetée (`preuves/J6/`) |
| ✅ | Un second passage sans changement de dépendances réutilise le cache | Journal de build : étapes `CACHED`, y compris après correction de `ARG REVISION` |
| ✅ | Actions épinglées par SHA de commit, `permissions:` minimales | Lecture du workflow ; Dependabot met à jour les SHA |
| ✅ | Une PR ne pousse aucune image et ne déploie rien | Aucune étape de connexion Azure dans les jobs de PR |
| ✅ | Push direct sur `main` refusé, y compris pour l'administrateur | Preuve dans `preuves/J6/` |
| ✅ | Fusion bloquée tant que les contrôles requis ne sont pas verts, même avec `--admin` | Preuve dans `preuves/J6/` |
| ✅ | Connexion à Azure par OIDC, aucun secret applicatif dans GitHub | `gh secret list` vide ; seules des variables d'identifiants publics |
| ✅ | Images publiées avec le tag du commit, SBOM et provenance | `az acr repository show-tags` ; attestations attachées |
| ✅ | Chaque fusion crée une nouvelle révision des deux applications | `az containerapp revision list` |

## Azure

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | `deploy.sh` crée tout depuis zéro | Exécution sur un abonnement sans groupe de ressources |
| ✅ | `deploy.sh` est rejouable | Seconde exécution : aucune ressource recréée, code de sortie 0 |
| ☐ | `destroy.sh` supprime tout, puis `deploy.sh` refonctionne | Cycle complet documenté |
| ✅ | Scripts sûrs | shellcheck propre ; `set -euo pipefail` ; refus de s'exécuter sans les variables requises |
| ✅ | Compte administrateur du registre désactivé ; tirage par identité managée | `az acr show --query adminUserEnabled` = `false` |
| ✅ | Backend injoignable depuis Internet | Ingress interne ; `curl` de son nom public renvoie la page 404 de la plateforme |
| ✅ | Frontend en HTTPS uniquement | `allowInsecure: false` ; HTTP redirigé |
| ✅ | `/health` répond `200 {"status":"ok"}` via le frontend | `curl` dans `preuves/J4/` |
| ✅ | Connexion PostgreSQL chiffrée, schéma appliqué une seule fois | `sslmode` dans l'URL ; journal du script |
| ✅ | Un **Participant** et un **Résultat** persistent après redémarrage | Preuve dans `preuves/J5/` |
| ✅ | Alerte budgétaire en place | `az consumption budget list` |
| ✅ | Bonus : la mise à l'échelle automatique répond à la charge | `preuves/bonus` : 1 → 3 réplicas en 24 s, retour à 1 après le délai de réduction |
| ☐ | Bonus : sous-domaine personnalisé avec certificat géré | `curl https://<sous-domaine>` |

## Infrastructure as code

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | `fmt`, `validate`, `tflint` et Trivy propres en CI | Onglet Checks de la PR |
| ✅ | Versions de Terraform et des fournisseurs épinglées, lock file versionné | `.terraform.lock.hcl` présent |
| ☐ | `apply` depuis zéro dans un groupe de ressources dédié, puis `destroy` complet | Preuve dans `preuves/terraform/` |
| ✅ | Aucun secret versionné ; variables sensibles marquées `sensitive` | Lecture du code |
| ✅ | Correspondance avec `deploy.sh` | Tableau commande `az` ↔ ressource Terraform dans `infra/terraform/README.md` |
| ✅ | Graphe des dépendances généré | `infra/terraform/graphe.sh` → `graphe.svg` |

## Documentation et livrables

| ✓ | Contrôle | Vérification |
| --- | --- | --- |
| ✅ | Lancement local, déploiement, prérequis et nettoyage documentés | README |
| ✅ | Schémas d'architecture locale et cloud | Mermaid dans le README, `analyse-j1.md`, `conteneurisation.md` et `azure.md` |
| ✅ | Preuves datées par **Jalon**, sans secret | `preuves/J0/` à `preuves/J6/` |
| ✅ | Problèmes connus documentés | `docs/technique/problemes-connus.md` |
| ✅ | Section « Usage de l'IA » | README |
