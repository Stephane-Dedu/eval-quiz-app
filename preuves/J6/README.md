# J6 — Chaîne CI/CD

**Date :** 2026-11-26

| Section | Contenu |
| --- | --- |
| [J6-A](#j6-a--contrôles-obligatoires-avant-fusion) | Ruleset de `main`, push direct refusé, CRITICAL bloquante même avec `--admin` |
| [J6-B](#j6-b--déploiement-après-fusion) | CD : échec OIDC corrigé, passage approuvé, tags par SHA, révisions |
| [Démonstration](#démonstration-complète--une-question-modifiée-de-la-branche-à-azure) | Une **Question** modifiée : PR rouge puis verte, fusion, approbation, nouvelle révision, Question en ligne |

## J6-A : contrôles obligatoires avant fusion

### Le ruleset de `main`

Ruleset « Protection de main », **actif** (pas en mode évaluation), **sans aucune exception de contournement** : [`ruleset-main.json`](ruleset-main.json), exporté de l'API GitHub.

| Règle | Paramètre |
| --- | --- |
| Pull request obligatoire | 0 approbation requise (dépôt à un seul contributeur, voir plus bas), fils de discussion résolus, fusion par squash uniquement |
| Contrôles requis | `Lint et configuration`, `Image frontend (build et Trivy)`, `Image backend (build et Trivy)`, `Image db (build et Trivy)`, `Intégration (Compose)` ; branche à jour avec `main` |
| Interdits | Suppression de `main`, force push, historique non linéaire |
| Exceptions de contournement | Aucune, administrateur compris |

Depuis la [PR #16](https://github.com/Stephane-Dedu/eval-quiz-app/pull/16), un sixième contrôle est requis : `Terraform (fmt, validate, tflint)`. Comme les cinq premiers, il a été ajouté après son premier passage réel. L'export ci-dessus reflète cet état ; les preuves qui suivent datent d'avant, avec cinq contrôles.

Les noms des contrôles ont été relevés sur le premier passage réel de la CI (API `check-runs` du commit), pas devinés :

```console
$ gh api repos/Stephane-Dedu/eval-quiz-app/commits/<sha>/check-runs --jq '.check_runs[] | "\(.name)\t\(.app.slug)\t\(.conclusion)"'
Intégration (Compose)              github-actions              success
Image db (build et Trivy)          github-actions              success
Image backend (build et Trivy)     github-actions              success
Image frontend (build et Trivy)    github-actions              success
Lint et configuration              github-actions              success
Trivy                              github-advanced-security    success
```

`Trivy` (application `github-advanced-security`) est l'analyse de l'onglet Security alimentée par le rapport SARIF ; le blocage repose sur les contrôles des images.

### Une PR verte fusionne d'elle-même

[PR #6](https://github.com/Stephane-Dedu/eval-quiz-app/pull/6), qui ajoute la CI : `gh pr merge 6 --squash --auto` alors que les contrôles tournaient ; GitHub l'a fusionnée à 10:01:51 UTC, dès que les 5 contrôles requis sont passés au vert ([run](https://github.com/Stephane-Dedu/eval-quiz-app/actions/runs/45797044935)).

### Un push direct sur `main` est refusé, administrateur compris

```console
$ git push origin main
remote: error: GH013: Repository rule violations found for refs/heads/main.        
remote: Review all repository rules at https://github.com/Stephane-Dedu/eval-quiz-app/rules?ref=refs%2Fheads%2Fmain        
remote: 
remote: - Changes must be made through a pull request.        
remote: 
remote: - 5 of 5 required status checks are expected.        
remote: 
To github.com:Stephane-Dedu/eval-quiz-app.git
 ! [remote rejected] main -> main (push declined due to repository rule violations)
error: failed to push some refs to 'github.com:Stephane-Dedu/eval-quiz-app.git'
code de sortie : 1
```

### Une vulnérabilité CRITICAL bloque la fusion

[PR #7](https://github.com/Stephane-Dedu/eval-quiz-app/pull/7), test contrôlé fermé sans fusion. Elle ajoute au backend `lodash@4.17.11`, touchée par CVE-2019-10744 (CRITICAL). Aucune image n'est publiée depuis une PR : l'image vulnérable n'a jamais quitté le runner.

Étapes du job `Image backend (build et Trivy)` ([run](https://github.com/Stephane-Dedu/eval-quiz-app/actions/runs/45797680713)) : le build réussit, c'est bien le scan qui échoue.

```text
success   Run actions/checkout
success   Run docker/setup-buildx-action
success   Build
failure   Trivy (toute vulnérabilité CRITICAL bloque)
skipped   Trivy (vulnérabilité HIGH corrigeable bloque)
success   Trivy (rapport complet au format SARIF)
success   Publier le rapport dans l'onglet Security
```

Extrait du journal de l'étape en échec :

```text
Total: 1 (CRITICAL: 1)
│ lodash (package.json) │ CVE-2019-10744 │ CRITICAL │ fixed  │ 4.17.11           │ 4.17.12       │ nodejs-lodash: prototype pollution in defaultsDeep function │
##[error]Process completed with exit code 1.
```

Tentatives de fusion :

```console
$ gh pr merge 7 --squash
X Pull request Stephane-Dedu/eval-quiz-app#7 is not mergeable: the base branch policy prohibits the merge.
To have the pull request merged after all the requirements have been met, add the `--auto` flag.
To use administrator privileges to immediately merge the pull request, add the `--admin` flag.
code de sortie : 1

$ gh pr view 7 --json mergeStateStatus,mergeable
{"mergeStateStatus":"BLOCKED","mergeable":"MERGEABLE"}

$ gh pr merge 7 --squash --admin     # tentative de contournement administrateur
GraphQL: Repository rule violations found

Required status check "Image backend (build et Trivy)" is failing.

 (mergePullRequest)
code de sortie : 1
```

`gh` propose `--admin` pour contourner les règles : le ruleset n'ayant aucune exception, GitHub refuse aussi.

Une première version du test (image d'exécution repassée sur `node:20`) a été abandonnée avant la fin de son passage, annulé automatiquement par le push suivant : l'étape `apk upgrade` n'existe pas sur une image Debian, le build aurait échoué avant le scan, ce qui n'aurait rien prouvé sur Trivy.

### Limite : aucune approbation requise

Le dépôt n'a qu'un contributeur et GitHub interdit à l'auteur d'une PR de l'approuver : exiger une approbation bloquerait toute fusion. Conformément à `docs/04`, la règle n'est pas prétendue active : `required_approving_review_count` vaut 0, et passe à 1 dès qu'un second membre a les droits.

**Mesure compensatoire :** l'environnement GitHub `production` exige l'approbation d'un relecteur désigné. Aucune image n'est publiée et rien n'est déployé avant cette approbation explicite, tracée avec son commentaire (voir [J6-B](#j6-b--déploiement-après-fusion) et la [démonstration](#3-approbation-publication-déploiement)).

## J6-B : déploiement après fusion

Workflow [`cd.yml`](../../.github/workflows/cd.yml), déclenché par chaque push sur `main`. Étapes : approbation sur l'environnement `production`, rebuild, second scan Trivy, connexion OIDC, publication, nouvelles révisions, vérification ([CI/CD](../../docs/technique/ci-cd.md#cd--githubworkflowscdyml)).

### Premier passage : connexion OIDC refusée

[Run 45811954132](https://github.com/Stephane-Dedu/eval-quiz-app/actions/runs/45811954132), fusion de la [PR #10](https://github.com/Stephane-Dedu/eval-quiz-app/pull/10). Le build et les scans ont réussi, puis la connexion à Azure a échoué :

```text
AADSTS700213: No matching federated identity record found for presented assertion subject 'repo:Stephane-Dedu@105072484/eval-quiz-app@1472861267:environment:production'. Check your federated identity credential Subject, Audience and Issuer against the
```

GitHub signe les jetons de ce dépôt avec un sujet qui contient les identifiants immuables du compte et du dépôt. L'identifiant fédéré attendait le format classique `repo:Stephane-Dedu/eval-quiz-app:…`. Correctif dans la [PR #11](https://github.com/Stephane-Dedu/eval-quiz-app/pull/11). Rien n'a été publié ni déployé : la connexion précède la publication.

### Passage réussi, après approbation

[Run 45822217087](https://github.com/Stephane-Dedu/eval-quiz-app/actions/runs/45822217087), fusion de la PR #11, commit `3f5ab0d0e960081f74ca10d4b113621699b6223b`.

| Événement | Heure (UTC) |
| --- | --- |
| Push sur `main` (fusion) | 12:42:48 |
| Approbation de l'environnement `production` par Stephane-Dedu | avant 12:45:11 |
| Début du job | 12:45:11 |
| Fin, succès | 12:47:37 |

```console
$ gh api repos/Stephane-Dedu/eval-quiz-app/actions/runs/45822217087/approvals --jq '.[] | "\(.user.login) \(.state) \(.environments[].name)"'
Stephane-Dedu approved production
```

Étapes du job `Publier et déployer` :

```text
success  Run actions/checkout
success  Run docker/setup-buildx-action
success  Build backend
success  Build frontend
success  Trivy backend (CRITICAL bloque)
success  Trivy backend (HIGH corrigeable bloque)
success  Trivy frontend (CRITICAL bloque)
success  Trivy frontend (HIGH corrigeable bloque)
success  Connexion à Azure (OIDC)
success  Connexion au registre
success  Publication backend (SBOM, provenance)
success  Publication frontend (SBOM, provenance)
success  Révisions avant déploiement
success  Nouvelle révision du backend
success  Nouvelle révision du frontend
success  Vérification
```

Images publiées avec le SHA du commit de fusion (extrait du journal) :

```text
pushing manifest for crquizsdedu.azurecr.io/quiz-backend:3f5ab0d0e960081f74ca10d4b113621699b6223b@sha256:ccb77503408476fea98945a95d6b2e111db25e3bcf4044b0a4ca25c95b1f8048
pushing manifest for crquizsdedu.azurecr.io/quiz-frontend:3f5ab0d0e960081f74ca10d4b113621699b6223b@sha256:63a6a1a3b596e03ec96840ea43ad5276088872567794c7efb85c2fe3d3c7f522
```

```console
$ az acr repository show-tags -n crquizsdedu --repository quiz-backend
3f5ab0d0e960081f74ca10d4b113621699b6223b
4eaf1123785bfb715c2e21cd91250f126ce4501c
$ az acr repository show-tags -n crquizsdedu --repository quiz-frontend
3f5ab0d0e960081f74ca10d4b113621699b6223b
4eaf1123785bfb715c2e21cd91250f126ce4501c
```

Révisions avant et après, telles que le job les a affichées dans son résumé :

```text
Avant
Revision                  Active    Image
ca-quiz-backend--91t601e  True      crquizsdedu.azurecr.io/quiz-backend:4eaf1123785bfb715c2e21cd91250f126ce4501c
Revision                   Active    Image
ca-quiz-frontend--2le2jer  True      crquizsdedu.azurecr.io/quiz-frontend:4eaf1123785bfb715c2e21cd91250f126ce4501c
Après
Revision                  Active    Image
ca-quiz-backend--91t601e  True      crquizsdedu.azurecr.io/quiz-backend:4eaf1123785bfb715c2e21cd91250f126ce4501c
ca-quiz-backend--0000001  True      crquizsdedu.azurecr.io/quiz-backend:3f5ab0d0e960081f74ca10d4b113621699b6223b
Revision                   Active    Image
ca-quiz-frontend--2le2jer  True      crquizsdedu.azurecr.io/quiz-frontend:4eaf1123785bfb715c2e21cd91250f126ce4501c
ca-quiz-frontend--0000001  True      crquizsdedu.azurecr.io/quiz-frontend:3f5ab0d0e960081f74ca10d4b113621699b6223b
GET https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/health → 200
```

Chaque fusion crée une nouvelle révision de chacune des deux applications (`--0000001`), sur l'image taguée par le commit de fusion. Juste après la mise à jour, l'ancienne et la nouvelle révision apparaissent toutes deux actives, le temps de la bascule. En mode révision unique, l'ancienne est ensuite désactivée : seule la plus récente reste active ([J4](../J4/README.md#révisions)).

## Démonstration complète : une Question modifiée, de la branche à Azure

Scénario de `docs/06` : modification d'une **Question** → branche → Pull Request → contrôle Trivy → approbation → fusion → publication ACR → mise à jour d'Azure Container Apps. [PR #13](https://github.com/Stephane-Dedu/eval-quiz-app/pull/13), branche `feature/question-docker`.

### 1. Contrôle échoué, puis réussi

| Commit | Contenu | CI |
| --- | --- | --- |
| `f4396f9` | Première **Question** de `questions_docker.js` reformulée, et `lodash@4.17.11` ajouté au backend | ❌ [Run 45825188223](https://github.com/Stephane-Dedu/eval-quiz-app/actions/runs/45825188223) : `Image backend (build et Trivy)` échoue à l'étape `Trivy (toute vulnérabilité CRITICAL bloque)`, fusion `BLOCKED` |
| `0eb89e1` | `lodash` retiré | ✅ [Run 45825404428](https://github.com/Stephane-Dedu/eval-quiz-app/actions/runs/45825404428) : les 5 contrôles requis au vert |

Extrait du journal du job en échec :

```text
Total: 1 (CRITICAL: 1)
│ lodash (package.json) │ CVE-2019-10744 │ CRITICAL │ fixed  │ 4.17.11           │ 4.17.12       │ nodejs-lodash: prototype pollution in defaultsDeep function │
```

Le passage rouge apparaît « annulé » dans la liste des runs : son job backend avait déjà échoué quand le push du second commit a annulé le reste du passage (`concurrency`), devenu inutile.

### 2. Fusion

Fusion par squash (`1d38574`) : seule la modification de la **Question** arrive sur `main`, l'aller-retour de `lodash` disparaît.

```console
$ git show --stat 1d38574
 questions_docker.js | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

### 3. Approbation, publication, déploiement

[Run CD 45825854138](https://github.com/Stephane-Dedu/eval-quiz-app/actions/runs/45825854138) : créé à 13:06:03 UTC, en attente jusqu'à l'approbation, job de 13:06:50 à 13:09:35, succès.

```console
$ gh api repos/Stephane-Dedu/eval-quiz-app/actions/runs/45825854138/approvals --jq '…'
approbation : Stephane-Dedu approved production — Démonstration docs/06 : question Docker reformulée (PR #13), contrôles verts après retrait de lodash.
```

Révisions avant et après :

```text
Avant
ca-quiz-backend	ca-quiz-backend--0000004	quiz-backend:05780a476cbbe32748d63ca3ca59cc14ee104388
ca-quiz-frontend	ca-quiz-frontend--0000004	quiz-frontend:05780a476cbbe32748d63ca3ca59cc14ee104388
Après
ca-quiz-backend	ca-quiz-backend--0000005	quiz-backend:1d38574f52cd9a7f316ba4fb6e08f1bb9b336de2
ca-quiz-frontend	ca-quiz-frontend--0000005	quiz-frontend:1d38574f52cd9a7f316ba4fb6e08f1bb9b336de2
```

### 4. La nouvelle Question est en ligne

Vite produit un fichier JavaScript par **Sujet**, au nom haché par son contenu. Le fichier des Questions Docker a changé de nom, et son contenu porte la nouvelle formulation :

```console
$ curl -s https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/assets/questions_docker-isXo3atz.js | grep -o 'Quelle commande[^?]*Dockerfile ?'
Quelle commande est utilisée pour créer une nouvelle image à partir d'un Dockerfile ?

$ curl -s https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/assets/questions_docker-CZzS7tH0.js | grep -o 'Quelle commande[^?]*Dockerfile ?'
Quelle commande construit une image Docker à partir d'un Dockerfile ?
```

Le navigateur récupère ce nouveau fichier dès le chargement suivant : les pages HTML sont servies en `no-cache`, et le nouveau nom de fichier contourne le cache d'un an des fichiers hachés.
