#!/usr/bin/env bash
# Test d'intégration de bout en bout.
#
# Prouve que frontend, backend et base communiquent, ce que /health seul ne
# prouve pas (il répond 200 même sans base). Sert en local, en CI et contre
# Azure.
#
# Usage   : ./scripts/smoke-test.sh [URL]        (défaut : http://localhost:8087)
# Requiert : curl, jq ; ADMIN_USERNAME et ADMIN_PASSWORD dans l'environnement
#            (chargés depuis .env s'ils sont absents et que .env existe).
#
# Limite : l'inscription est limitée à 5 par IP et par 15 minutes par le
# backend ; au-delà, le test échoue en 429 jusqu'à la fin de la fenêtre.

set -euo pipefail

BASE_URL="${1:-${BASE_URL:-http://localhost:8087}}"
BASE_URL="${BASE_URL%/}"

if [[ -z "${ADMIN_PASSWORD:-}" && -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source ./.env
  set +a
fi
: "${ADMIN_USERNAME:?ADMIN_USERNAME manquant}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD manquant}"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "$cmd est requis" >&2; exit 2; }
done

step() { printf '\n▶ %s\n' "$*"; }
ok() { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*" >&2; exit 1; }

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT

# request MÉTHODE CHEMIN [JSON] [JETON] : remplit STATUS et BODY.
request() {
  local method=$1 path=$2 data=${3:-} token=${4:-}
  local args=(-sS -o "$body_file" -w '%{http_code}' -X "$method" --max-time 15)
  [[ -n $data ]] && args+=(-H 'Content-Type: application/json' --data "$data")
  [[ -n $token ]] && args+=(-H "Authorization: Bearer $token")
  STATUS=$(curl "${args[@]}" "$BASE_URL$path") || fail "$method $path : pas de réponse"
  BODY=$(<"$body_file")
}

expect_status() {
  [[ $STATUS == "$1" ]] || fail "$2 : HTTP $STATUS au lieu de $1 — $BODY"
  ok "$2 (HTTP $STATUS)"
}

email="smoke-$(date +%s)-$RANDOM@example.com"

echo "Test d'intégration sur $BASE_URL"

step "Santé du backend, via le frontend"
request GET /health
expect_status 200 "GET /health"
[[ $(jq -r .status <<<"$BODY") == ok ]] || fail "réponse inattendue : $BODY"
ok 'corps {"status":"ok"}'

step "Pages servies par Nginx"
request GET /
expect_status 200 "GET /"
grep -q 'id="app"' <<<"$BODY" || fail "index.html inattendu"
request GET /gestion-quiz
expect_status 200 "GET /gestion-quiz"
grep -q 'id="login-form"' <<<"$BODY" || fail "gestion-quiz.html inattendu"

step "En-têtes de sécurité"
headers=$(curl -sS -D - -o /dev/null --max-time 15 "$BASE_URL/")
for header in content-security-policy x-content-type-options x-frame-options referrer-policy; do
  grep -qi "^$header:" <<<"$headers" || fail "en-tête $header absent"
done
ok "CSP, nosniff, X-Frame-Options et Referrer-Policy présents"

step "Inscription d'un Participant"
request POST /api/users "$(jq -nc --arg e "$email" '{firstname: "Smoke", email: $e, website: ""}')"
expect_status 201 "POST /api/users"
user_id=$(jq -r .id <<<"$BODY")
[[ $user_id =~ ^[1-9][0-9]*$ ]] || fail "identifiant invalide : $BODY"
ok "Participant n°$user_id"

step "Enregistrement d'un Résultat"
payload=$(jq -nc --argjson u "$user_id" --arg q "Question du test d'intégration" \
  '{userId: $u, score: 1, totalQuestions: 1,
    answers: [{questionIndex: 0, questionText: $q, userAnswer: "A",
               correctAnswer: "A", isCorrect: true, timeSpentMs: 1000}]}')
request POST /api/results "$payload"
expect_status 201 "POST /api/results"
ok "Résultat n°$(jq -r .quizResultId <<<"$BODY")"

step "Lecture côté Administrateur"
request POST /api/admin/login \
  "$(jq -nc --arg u "$ADMIN_USERNAME" --arg p "$ADMIN_PASSWORD" '{username: $u, password: $p}')"
expect_status 200 "POST /api/admin/login"
token=$(jq -r .token <<<"$BODY")
request GET "/api/admin/results?limit=100" "" "$token"
expect_status 200 "GET /api/admin/results"
jq -e --arg e "$email" '.results[] | select(.email == $e)' <<<"$BODY" >/dev/null \
  || fail "le Résultat de $email est absent de la liste"
ok "le Résultat de $email est relu depuis PostgreSQL"

printf '\n✅ Frontend, backend et base communiquent.\n'
