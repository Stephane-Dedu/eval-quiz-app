# Bonus — Mise à l'échelle automatique sur Azure

**Date :** 2026-11-26 (heures UTC)
**Cible :** `GET /` sur `ca-quiz-frontend`, page statique servie par Nginx

`docs/05` précise que le nombre de réplicas de Docker Compose ne prouve rien : seule compte la mise à l'échelle d'Azure Container Apps.

## Règle

| Réglage | Valeur |
| --- | --- |
| Réplicas | 0 au minimum, 3 au maximum |
| Règle | HTTP, 20 requêtes simultanées par réplica |
| Réduction | Après 5 minutes sans charge suffisante (délai par défaut de la plateforme) |

La charge vise la page d'accueil et non `/api` ou `/health` : ces routes passent par le limiteur du backend (100 requêtes par 15 minutes et par IP) et répondraient 429 presque immédiatement.

## Test

```console
$ hey -z 120s -c 100 https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/
  Total:	120.0478 secs
  Slowest:	0.5160 secs
  Fastest:	0.0137 secs
  Average:	0.0534 secs
  Requests/sec:	1872.2044
  95% in 0.1048 secs
  99% in 0.1900 secs

Status code distribution:
  [200]	224754 responses
```

100 connexions simultanées pendant 2 minutes : 224 754 requêtes, toutes en 200.

## Réplicas avant, pendant et après

Relevé toutes les 10 à 13 secondes avec `az containerapp replica list -g rg-quiz-gwc -n ca-quiz-frontend --query "length(@)"` ([relevé complet](replicas.txt)) :

| Moment | Heure | Réplicas |
| --- | --- | ---: |
| Avant la charge | 13:12:42 | 1 |
| Début de la charge | 13:13:10 | 1 |
| Pendant la charge | 13:13:34 | **3** |
| Fin de la charge | 13:15:10 | 3 |
| Après le délai de réduction | 13:21:55 | 1 |

- **Montée :** 24 secondes après le début de la charge, l'application atteint son maximum de 3 réplicas. 100 connexions ÷ 20 par réplica en demanderaient 5 : le plafond s'applique.
- **Descente :** 6 min 45 s après la fin de la charge, retour à 1 réplica. Les 5 minutes de délai de la plateforme, plus la granularité du relevé.
- **Sans erreur :** latence moyenne de 53 ms, 99 % des requêtes sous 190 ms.
