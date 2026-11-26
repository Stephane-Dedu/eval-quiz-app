#!/usr/bin/env bash
# Régénère le graphe des dépendances entre ressources (graphe.svg).
# Requiert : terraform, Graphviz (dot).
set -euo pipefail
cd "$(dirname "$0")"
terraform init -backend=false -input=false >/dev/null
terraform graph | dot -Tsvg > graphe.svg
echo "graphe.svg régénéré"
