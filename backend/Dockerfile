# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Étape 1 — dépendances de production uniquement.
# ---------------------------------------------------------------------------
FROM node:26.13.1-alpine3.24@sha256:6bd9ab43c0ec0190ca7b2d193906cb8b7edf6e7f4afa43ddeccd6452710bffb5 AS deps

WORKDIR /app

# Cette couche n'est reconstruite que si le lockfile change.
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev --ignore-scripts --no-audit --no-fund

# ---------------------------------------------------------------------------
# Étape 2 — exécution : Node, tini, les dépendances et server.js, rien d'autre.
# ---------------------------------------------------------------------------
FROM node:26.13.1-alpine3.24@sha256:6bd9ab43c0ec0190ca7b2d193906cb8b7edf6e7f4afa43ddeccd6452710bffb5 AS runtime

ARG REVISION=inconnue
LABEL org.opencontainers.image.title="quiz-backend" \
      org.opencontainers.image.description="Quiz App : API Express" \
      org.opencontainers.image.source="https://github.com/Stephane-Dedu/eval-quiz-app" \
      org.opencontainers.image.revision="${REVISION}"

# apk upgrade : correctifs Alpine publiés depuis la construction de l'image de base.
# tini devient le processus 1 et transmet SIGTERM à Node, qui n'installe
# aucun gestionnaire de signal : sans lui, l'arrêt attend 10 s puis SIGKILL.
# npm ne sert plus à l'exécution : le retirer supprime ses dépendances
# embarquées de l'image et de la surface d'attaque.
RUN apk upgrade --no-cache \
    && apk add --no-cache tini=0.19.0-r3 \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

ENV NODE_ENV=production \
    PORT=3007

WORKDIR /app

# Fichiers possédés par root : l'utilisateur node (uid 1000) peut les lire, pas les modifier.
COPY --from=deps /app/node_modules ./node_modules
COPY package.json server.js ./

USER 1000:1000

EXPOSE 3007

# /health partage le limiteur de 100 requêtes / 15 min : 30 s d'intervalle
# en consomment 30, depuis 127.0.0.1, compteur distinct des vrais clients.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=2s --retries=3 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:3007/health"]

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
