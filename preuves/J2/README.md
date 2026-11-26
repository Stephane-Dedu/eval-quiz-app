# J2 — Sécurité des images

**Date :** 2026-11-26
**Outils :** Trivy 0.76.2 (base du 2026-11-26), hadolint 2.15.1

| Rapport | Contenu |
| --- | --- |
| [État initial](initial/rapport-trivy.md) | Dockerfiles naïfs, détail des CRITICAL et des paquets les plus touchés |
| [État final](final/rapport-trivy.md) | Dockerfiles durcis |

## Du naïf au durci, étape par étape

Chaque étape a été construite puis scannée ; une seule chose change à chaque fois.

| Étape | Changement | Frontend | | Backend | |
| --- | --- | ---: | ---: | ---: | ---: |
| | | **Taille** | **CRITICAL / HIGH** | **Taille** | **CRITICAL / HIGH** |
| 0 | État initial : `node:20` complète, une étape, root | 1143 Mo | 74 / 1819 | 1111 Mo | 74 / 1819 |
| A | `node:26`, version maintenue | 1308 Mo | 3 / 192 | 1275 Mo | 3 / 192 |
| B | `node:26-alpine` | 229 Mo | 0 / 6 | 196 Mo | 0 / 6 |
| C | Multi-étapes : Nginx non-root pour le frontend ; backend sans npm, avec tini, uid 1000 | 61 Mo | 1 / 13 | 192 Mo | 0 / 0 |
| D | `apk upgrade` à la construction | **74 Mo** | **0 / 0** | **198 Mo** | **0 / 0** |

Pour PostgreSQL, utilisé seulement en local :

| Image | Taille | CRITICAL / HIGH |
| --- | ---: | ---: |
| `postgres:18` (Debian, état initial) | 500 Mo | 2 / 99 |
| `postgres:18.7-alpine3.24` | 298 Mo | 1 / 26 |
| `quiz-db` : `apk upgrade`, sans `gosu`, uid 70 | 306 Mo | **0 / 0** |

## Corrections et justifications

| Correction | Ce qu'elle supprime | Pourquoi |
| --- | --- | --- |
| **Node.js 26 au lieu de 20** | 71 CRITICAL, 1627 HIGH | Node.js 20 est en fin de vie depuis le 30 avril 2026 : son image n'est plus reconstruite, ses paquets Debian ne reçoivent plus de correctifs. Node.js 26 est la version LTS active. |
| **Alpine au lieu de Debian complète** | 3 CRITICAL, 186 HIGH, ~1 Go | L'image complète embarque compilateurs, en-têtes du noyau et ImageMagick, inutiles pour exécuter l'application. Alpine ne contient que le minimum. Distroless, encore plus réduite, a été écartée : sans shell, impossible de diagnostiquer un conteneur en direct. |
| **Frontend servi par Nginx, sans Node** | 168 Mo | Le frontend n'est qu'un ensemble de fichiers statiques une fois construit. Node et `node_modules` restent dans l'étape de construction. |
| **npm retiré de l'image backend** | 6 HIGH | npm ne sert qu'à installer les dépendances, dans l'étape `deps`. Les 6 HIGH étaient dans les dépendances embarquées par npm, pas dans l'application. |
| **`gosu` retiré de l'image PostgreSQL** | 1 CRITICAL, 25 HIGH | `gosu` sert à quitter root au démarrage. Le conteneur démarre directement en utilisateur `postgres`, donc `gosu` ne sert plus ; son binaire Go embarque une bibliothèque standard vulnérable. |
| **`apk upgrade` à la construction** | 1 CRITICAL, 14 HIGH et toutes les MEDIUM et LOW restantes | L'image Nginx de base date du 2026-10-19 ; des correctifs Alpine sont sortis depuis (brotli, curl, expat, libxml2, musl, zlib, OpenSSL). La mise à jour les applique sans attendre la republication de l'image de base. Contrepartie : le frontend prend 13 Mo, car les anciens paquets restent dans la couche de l'image de base. |

## Vulnérabilités restantes

Aucune, toutes sévérités confondues, sur les trois images. `.trivyignore` n'est donc pas nécessaire.

Ce résultat vaut pour la base de vulnérabilités du 2026-11-26. De nouvelles CVE seront publiées : c'est pourquoi la CI rescanne à chaque PR et bloque sur toute CRITICAL et sur toute HIGH corrigeable.

## Autres durcissements vérifiés

| Contrôle | Résultat |
| --- | --- |
| hadolint sur les trois Dockerfiles | Aucun avertissement |
| Utilisateur d'exécution | frontend uid 101, backend uid 1000, base uid 70 |
| Images de base | Épinglées par digest multi-architecture (`@sha256:…`), valables en arm64 et en amd64 |
| Contexte de build | Liste blanche dans chaque `.dockerignore` : un nouveau fichier (secret, preuve, documentation) en est exclu par défaut |
| Arrêt (`docker stop`) | backend 0,26 s, frontend 0,23 s ; sans tini, Node en processus 1 ignore SIGTERM et l'arrêt attend 10 s |
| Système de fichiers en lecture seule, sans capacités Linux | Les trois images démarrent et restent saines avec `--read-only --cap-drop ALL --security-opt no-new-privileges:true` |
| Cache des couches | Après modification d'une **Question**, `npm ci` est `CACHED` ; seules la copie des fichiers de **Questions** et la construction Vite sont rejouées |

Extrait du build après modification de `questions_docker.js` :

```text
CACHED   build 2/8    WORKDIR /app
CACHED   build 3/8    COPY package.json package-lock.json ./
CACHED   build 4/8    RUN --mount=type=cache,target=/root/.npm npm ci --ignore-scripts …
CACHED   build 5/8    COPY vite.config.js index.html gestion-quiz.html main.js style.css ./
CACHED   build 6/8    COPY public ./public
EXÉCUTÉ  build 7/8    COPY questions_*.js ./
EXÉCUTÉ  build 8/8    RUN npm run build
CACHED   runtime 2/3  COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
CACHED   runtime 3/3  COPY --from=build /app/dist /usr/share/nginx/html
```

La dernière copie reste en cache parce que la modification testée était un commentaire, retiré par Vite : les fichiers produits étaient identiques.
