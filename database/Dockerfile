# syntax=docker/dockerfile:1

# PostgreSQL local (Docker Compose). Sur Azure, la base est Neon : cette
# image ne sert qu'en local et en CI.
FROM postgres:18.7-alpine3.24@sha256:0115267ab5a509022df9319c77be365cef335adb71556c75f60f5360ee247e71

LABEL org.opencontainers.image.title="quiz-db" \
      org.opencontainers.image.description="Quiz App : PostgreSQL avec le schéma de l'application" \
      org.opencontainers.image.source="https://github.com/Stephane-Dedu/eval-quiz-app"

# - apk upgrade : correctifs Alpine publiés depuis l'image de base.
# - gosu ne sert qu'à quitter root au démarrage. Le conteneur démarre ici
#   directement en utilisateur postgres, donc gosu est inutile ; son binaire
#   Go embarque une bibliothèque standard vulnérable.
RUN apk upgrade --no-cache \
    && rm /usr/local/bin/gosu

# Exécuté par l'image officielle uniquement à la création d'un volume vide :
# init.sql n'est pas rejouable (CREATE TABLE sans IF NOT EXISTS).
COPY init.sql /docker-entrypoint-initdb.d/01-schema.sql

# Utilisateur postgres de l'image Alpine (uid 70).
USER 70:70

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --start-interval=2s --retries=5 \
    CMD ["sh", "-c", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\" -h 127.0.0.1"]
