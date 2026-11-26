# J5 — PostgreSQL externe chiffré (Neon)

**Date :** 2026-11-26
**Base :** Neon, PostgreSQL 18.7, région AWS `eu-central-1` (Francfort)

## Connexion chiffrée et vérifiée

URL fournie au backend, identifiants masqués :

```text
postgresql://neondb_owner:********@ep-dark-mode-bgey9q65.c-9.eu-central-1.aws.neon.tech/neondb?sslmode=verify-full
```

- **`sslmode=verify-full`** chiffre la connexion, vérifie le certificat de Neon auprès des autorités de confiance et contrôle qu'il correspond bien au nom d'hôte. `sslmode=require`, proposé par défaut par Neon, chiffre sans vérifier l'identité du serveur.
- **Côté backend**, le pilote `pg` traduit `verify-full` en connexion TLS avec vérification (`rejectUnauthorized`), à partir des autorités embarquées par Node.js.
- **Côté `psql`**, utilisé par `deploy.sh` pour le schéma, `sslrootcert=system` est ajouté pour lui faire utiliser les autorités du système.
- **`deploy.sh` refuse une `DATABASE_URL` sans `sslmode`.**
- `pg_stat_ssl` côté Neon affiche `ssl = f` : cette vue décrit la connexion entre le proxy de Neon et son nœud de calcul, pas la nôtre. Notre connexion s'arrête au proxy, en TLS vérifié ; sans certificat valide, `verify-full` aurait fait échouer la connexion.

## Secrets

| Secret | Où il vit | Comment il y arrive |
| --- | --- | --- |
| `DATABASE_URL` | Secret `database-url` de `ca-quiz-backend` | `deploy.sh`, depuis l'environnement de l'opérateur (fichier `.env.azure`, ignoré par git) |
| `JWT_SECRET`, `ADMIN_PASSWORD`, `RESEND_API_KEY` | Secrets de `ca-quiz-backend` | Idem |

```console
$ az containerapp secret list -g rg-quiz-gwc -n ca-quiz-backend --query '[].name'
jwt-secret
admin-password
resend-api-key
database-url

$ az containerapp show -g rg-quiz-gwc -n ca-quiz-backend --query 'properties.template.containers[0].env'
Nom              Reference       Valeur
---------------  --------------  ------------
JWT_SECRET       jwt-secret
ADMIN_PASSWORD   admin-password
RESEND_API_KEY   resend-api-key
ADMIN_USERNAME                   admin
SECRETS_VERSION                  7a17b0cbcfce
DATABASE_URL     database-url
```

Les variables du conteneur ne contiennent que des références (`secretRef`), jamais les valeurs. `SECRETS_VERSION` est une empreinte des secrets, pas un secret : quand un secret change, elle change, ce qui crée une révision qui relit les nouvelles valeurs. GitHub ne détient aucun de ces secrets : le CD ne fait que changer d'image ([ADR 0003](../../docs/adr/0003-secrets-container-apps-plutot-que-key-vault.md), [ADR 0004](../../docs/adr/0004-cd-sans-secret-applicatif.md)).

## Initialisation du schéma, une seule fois

`database/init.sql` n'est pas rejouable (`CREATE TABLE` sans `IF NOT EXISTS`). `deploy.sh` vérifie d'abord si la table `users` existe.

Premier déploiement :

```text
▶ Schéma PostgreSQL
  init.sql appliqué
```

Déploiements suivants ([preuve J3](../J3/README.md#un-second-passage-ne-recrée-rien)) :

```text
▶ Schéma PostgreSQL
  tables déjà présentes : init.sql n'est pas rejoué
```

## Inscription et Résultat enregistrés

```console
$ ./scripts/smoke-test.sh https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io

▶ Santé du backend, via le frontend
  ✓ GET /health (HTTP 200)
  ✓ corps {"status":"ok"}

▶ Pages servies par Nginx
  ✓ GET / (HTTP 200)
  ✓ GET /gestion-quiz (HTTP 200)

▶ En-têtes de sécurité
  ✓ CSP, nosniff, X-Frame-Options et Referrer-Policy présents

▶ Inscription d'un Participant
  ✓ POST /api/users (HTTP 201)
  ✓ Participant n°1

▶ Enregistrement d'un Résultat
  ✓ POST /api/results (HTTP 201)
  ✓ Résultat n°1

▶ Lecture côté Administrateur
  ✓ POST /api/admin/login (HTTP 200)
  ✓ GET /api/admin/results (HTTP 200)
  ✓ le Résultat de smoke-1795696903-6569@example.com est relu depuis PostgreSQL

✅ Frontend, backend et base communiquent.
```

Parcours complet dans un navigateur, sur Azure (`./scripts/captures.sh preuves/J5/captures <url>`) : inscription, 20 **Questions**, **Résultat** enregistré, puis tableau d'administration. Aucune erreur en console, politique de sécurité du contenu comprise ([`console.txt`](captures/console.txt) est vide).

| Résultat enregistré | Tableau d'administration |
| --- | --- |
| ![Résultat](captures/04-resultat.png) | ![Tableau](captures/06-tableau-administrateur.png) |

## Persistance après redémarrage du backend

```console
== Avant redémarrage : données dans Neon
$ psql "$DATABASE_URL" -c "SELECT u.firstname AS prenom, u.email, r.score, r.total_questions AS questions, r.completed_at AS termine FROM users u JOIN quiz_results r ON r.user_id = u.id ORDER BY r.id"
 prenom |               email               | score | questions |          termine           
--------+-----------------------------------+-------+-----------+----------------------------
 Smoke  | smoke-1795696903-6569@example.com |     1 |         1 | 2026-11-26 12:41:44.968279
 Démo   | demo-1795696923565@example.com    |     5 |        20 | 2026-11-26 12:42:06.49304
(2 rows)

$ az containerapp revision restart -g rg-quiz-gwc -n ca-quiz-backend --revision ca-quiz-backend--91t601e
Restart succeeded
révision ca-quiz-backend--91t601e : Running, /health → 200

== Après redémarrage : lecture par l'API d'administration
{"prenom":"Démo","email":"demo-1795696923565@example.com","tentatives":"1","meilleur":5}
{"prenom":"Smoke","email":"smoke-1795696903-6569@example.com","tentatives":"1","meilleur":1}

== Après redémarrage : données dans Neon
 prenom |               email               | score | questions |          termine           
--------+-----------------------------------+-------+-----------+----------------------------
 Smoke  | smoke-1795696903-6569@example.com |     1 |         1 | 2026-11-26 12:41:44.968279
 Démo   | demo-1795696923565@example.com    |     5 |        20 | 2026-11-26 12:42:06.49304
(2 rows)

$ az containerapp logs show -g rg-quiz-gwc -n ca-quiz-backend --type console --tail 20 | grep 'Server running'
2026-11-26T12:42:47.7023311+00:00 F Server running on port 3007
```

Le backend a redémarré à 12:42:47, après son premier démarrage à 12:38:51. Le **Participant** et le **Résultat** sont toujours lus par l'API d'administration : ils vivent dans Neon, pas dans le conteneur.
