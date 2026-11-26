# J6 — Chaîne CI/CD

**Date :** 2026-11-26

## J6-A : contrôles obligatoires avant fusion

### Le ruleset de `main`

Ruleset « Protection de main », **actif** (pas en mode évaluation), **sans aucune exception de contournement** : [`ruleset-main.json`](ruleset-main.json), exporté de l'API GitHub.

| Règle | Paramètre |
| --- | --- |
| Pull request obligatoire | 0 approbation requise (dépôt à un seul contributeur, voir plus bas), fils de discussion résolus, fusion par squash uniquement |
| Contrôles requis | `Lint et configuration`, `Image frontend (build et Trivy)`, `Image backend (build et Trivy)`, `Image db (build et Trivy)`, `Intégration (Compose)` ; branche à jour avec `main` |
| Interdits | Suppression de `main`, force push, historique non linéaire |
| Exceptions de contournement | Aucune, administrateur compris |

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
