# Diagnostic : le backend a-t-il besoin de la base pour démarrer ?

**Date :** 2026-11-26
**Image :** `quiz-backend:initial`

Le sujet demande de diagnostiquer et d'expliquer si le backend a besoin d'une base opérationnelle pour démarrer (`docs/01`, `docs/03` J4).

## Sans `RESEND_API_KEY` : le backend ne démarre pas

```console
$ docker run --rm quiz-backend:initial
…
        throw new Error(
Error: Missing API key. Pass it to the constructor `new Resend("re_123")`
```

`server.js` crée le client Resend au chargement du module (`new Resend(process.env.RESEND_API_KEY)`), et cette version du SDK refuse une clé absente. Le processus s'arrête avant d'ouvrir le port.

## Avec une clé factice et sans base : le backend démarre

```console
$ docker run -d --rm -e RESEND_API_KEY=re_factice -p 13007:3007 quiz-backend:initial
$ curl -s -w ' HTTP %{http_code}\n' localhost:13007/health
{"status":"ok"} HTTP 200
$ curl -s -w ' HTTP %{http_code}\n' -X POST -H 'Content-Type: application/json' \
    -d '{"firstname":"Test","email":"t@example.com","website":""}' localhost:13007/api/users
{"error":"Internal server error"} HTTP 500
$ docker logs <conteneur>
…
  syscall: 'connect',
  address: '127.0.0.1',
  port: 5432
```

## Explication

- **Le démarrage ne dépend pas de la base.** Le pool `pg` ne se connecte qu'à la première requête SQL.
- **`/health` ne prouve donc pas que l'application fonctionne.** Il répond 200 sans jamais interroger la base ; seule une route qui écrit en base (inscription, Résultat) révèle une base absente.
- **Sans `DATABASE_URL`, le pilote `pg` vise `127.0.0.1:5432`**, c'est-à-dire le conteneur backend lui-même. D'où la connexion refusée.
- **Conséquences pour la suite :**
  - En local, Compose fait attendre au backend que PostgreSQL accepte les connexions. Ce n'est pas pour qu'il démarre, mais pour que la première inscription réussisse.
  - Le test d'intégration passe par une inscription et un Résultat, pas seulement par `/health`.
  - Une clé Resend factice est fournie tant que l'envoi d'email n'est pas configuré.
