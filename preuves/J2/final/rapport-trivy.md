# J2 — Scan Trivy de l'état final

**Date :** 2026-11-26
**Outil :** Trivy 0.76.2, base de vulnérabilités du 2026-11-26
**Images :** construites localement (linux/arm64) depuis les Dockerfiles durcis. La CI rejoue ce scan sur les images linux/amd64 à chaque PR.

```console
$ docker build -t quiz-frontend:durcie .
$ docker build -t quiz-backend:durcie backend
$ docker build -t quiz-db:durcie database
$ trivy image --scanners vuln --format json -o <rapport>.json <image>
```

| Image | Système | Taille | CRITICAL | HIGH | MEDIUM | LOW | CRITICAL corrigeables | HIGH corrigeables |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `quiz-frontend:durcie` | alpine 3.24.2 | 74 Mo | 0 | 0 | 0 | 0 | 0 | 0 |
| `quiz-backend:durcie` | alpine 3.24.4 | 198 Mo | 0 | 0 | 0 | 0 | 0 | 0 |
| `quiz-db:durcie` | alpine 3.24.4 | 306 Mo | 0 | 0 | 0 | 0 | 0 | 0 |

Aucune vulnérabilité, toutes sévérités confondues : il n'y a donc rien à justifier ni à mettre dans `.trivyignore`.
