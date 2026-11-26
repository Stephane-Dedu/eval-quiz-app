# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Étape 1 — construction des fichiers statiques avec Vite.
# Rien de cette étape n'arrive dans l'image finale, sauf le dossier dist/.
# ---------------------------------------------------------------------------
FROM node:26.13.1-alpine3.24@sha256:6bd9ab43c0ec0190ca7b2d193906cb8b7edf6e7f4afa43ddeccd6452710bffb5 AS build

WORKDIR /app

# Dépendances d'abord : cette couche n'est reconstruite que si le lockfile
# change. Le cache npm est monté pour ne pas retélécharger les paquets.
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --ignore-scripts --no-audit --no-fund

# Puis le code, du moins au plus souvent modifié : modifier une Question
# n'invalide que la dernière copie et le build.
COPY vite.config.js index.html gestion-quiz.html main.js style.css ./
COPY public ./public
COPY questions_*.js ./
RUN npm run build

# ---------------------------------------------------------------------------
# Étape 2 — Nginx non-root (uid 101, port 8080) : fichiers statiques et
# relais de /api et /health vers le backend.
# ---------------------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.31.7-alpine3.24@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e AS runtime

ARG REVISION=inconnue
LABEL org.opencontainers.image.title="quiz-frontend" \
      org.opencontainers.image.description="Quiz App : fichiers statiques et relais API (Nginx)" \
      org.opencontainers.image.source="https://github.com/Stephane-Dedu/eval-quiz-app" \
      org.opencontainers.image.revision="${REVISION}"

# Valeur pour Docker Compose ; Azure Container Apps la remplace.
ENV BACKEND_ORIGIN=http://backend:3007

# Correctifs de sécurité Alpine publiés depuis la construction de l'image de
# base (elle date du 2026-10-19). Root le temps de l'installation, puis retour
# à l'utilisateur non-root de l'image (uid 101).
USER 0
RUN apk upgrade --no-cache
USER 101

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=2s --retries=3 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/"]
