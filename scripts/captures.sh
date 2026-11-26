#!/usr/bin/env bash
# Captures d'écran reproductibles du parcours complet (quiz et administration),
# prises par Playwright dans un conteneur : aucun navigateur à installer.
#
# Usage   : ./scripts/captures.sh <dossier-de-sortie> [URL]
#           URL par défaut : l'application locale vue depuis un conteneur
#           (http://host.docker.internal:8087).
# Requiert : Docker ; ADMIN_USERNAME et ADMIN_PASSWORD dans l'environnement
#            (chargés depuis .env s'ils sont absents et que .env existe).
#
# Le script échoue si la console du navigateur affiche une erreur, par exemple
# une ressource bloquée par la politique CSP.

set -euo pipefail

PLAYWRIGHT_VERSION=1.65.1

out_dir=${1:?Usage : $0 <dossier-de-sortie> [URL]}
base_url=${2:-http://host.docker.internal:8087}

if [[ -z "${ADMIN_PASSWORD:-}" && -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source ./.env
  set +a
fi
: "${ADMIN_USERNAME:?ADMIN_USERNAME manquant}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD manquant}"

mkdir -p "$out_dir"
scripts_dir=$(cd "$(dirname "$0")/captures" && pwd)
out_dir=$(cd "$out_dir" && pwd)

docker run --rm --init --ipc=host \
  -v "$scripts_dir:/scripts:ro" \
  -v "$out_dir:/out" \
  -e BASE_URL="$base_url" -e OUT=/out \
  -e ADMIN_USERNAME -e ADMIN_PASSWORD \
  "mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-noble" \
  bash -c "cd /tmp \
    && npm init -y >/dev/null \
    && npm install --silent --no-audit --no-fund playwright@${PLAYWRIGHT_VERSION} \
    && cp /scripts/captures.mjs . \
    && node captures.mjs"
