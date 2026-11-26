# J4 — Container Apps

**Date :** 2026-11-26
**Application :** https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io

Deux Container Apps tirent leurs images de l'Azure Container Registry avec une identité managée. Seul le frontend est exposé, en HTTPS ; le backend n'est joignable que depuis l'environnement.

## Environnement

```console
$ az rest --method get --url …/managedEnvironments/cae-quiz?api-version=2026-07-01 --query '{…}'
{
  "chiffrementEntreApplications": true,
  "domaine": "blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io",
  "journaux": "log-analytics",
  "mode": "WorkloadProfiles",
  "region": "Belgium Central"
}
```

Le mode WorkloadProfiles est indispensable : le mode Express, créé par défaut par Azure CLI, n'a pas de découverte de services interne. Le frontend y obtenait un 404 en appelant le backend ([ADR 0005](../../docs/adr/0005-environnement-workload-profiles.md)).

## Applications : ingress, registre, identité

État capturé à 13:30 UTC, juste après le déploiement de la PR #14 (image `df88c2c…`, révision `--0000006`). Chaque fusion suivante crée une nouvelle révision par le CD ([J6](../J6/README.md#j6-b--déploiement-après-fusion)).

```console
$ az containerapp show -g rg-quiz-gwc -n ca-quiz-frontend --query '{…}'
{
  "cpu": 0.25,
  "fqdn": "ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io",
  "httpAutorise": false,
  "identiteRegistre": "/subscriptions/<abonnement>/resourcegroups/rg-quiz-gwc/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-quiz-pull",
  "identites": "UserAssigned",
  "image": "crquizsdedu.azurecr.io/quiz-frontend:df88c2cab964e4392f0288588ff8b0516dd52a65",
  "ingressExterne": true,
  "memoire": "0.5Gi",
  "portCible": 8080,
  "registre": "crquizsdedu.azurecr.io",
  "regleEchelle": {
    "concurrentRequests": "20"
  },
  "replicas": {
    "max": 3,
    "min": 0
  },
  "revision": "ca-quiz-frontend--0000006",
  "sondesDeclarees": null,
  "transport": "Auto"
}

$ az containerapp show -g rg-quiz-gwc -n ca-quiz-backend --query '{…}'
{
  "cpu": 0.25,
  "fqdn": "ca-quiz-backend.internal.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io",
  "httpAutorise": false,
  "identiteRegistre": "/subscriptions/<abonnement>/resourcegroups/rg-quiz-gwc/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-quiz-pull",
  "identites": "UserAssigned",
  "image": "crquizsdedu.azurecr.io/quiz-backend:df88c2cab964e4392f0288588ff8b0516dd52a65",
  "ingressExterne": false,
  "memoire": "0.5Gi",
  "portCible": 3007,
  "registre": "crquizsdedu.azurecr.io",
  "regleEchelle": {
    "concurrentRequests": "20"
  },
  "replicas": {
    "max": 3,
    "min": 0
  },
  "revision": "ca-quiz-backend--0000006",
  "sondesDeclarees": null,
  "transport": "Http"
}

```

| | Frontend | Backend |
| --- | --- | --- |
| Ingress | **externe**, HTTPS, port cible 8080 | **interne**, port cible 3007 |
| HTTP non chiffré | redirigé vers HTTPS (`allowInsecure: false`) | refusé |
| Tirage des images | identité `id-quiz-pull` (`AcrPull`) | idem |
| Sondes | TCP par défaut (aucune déclarée) | TCP par défaut : `/health` est soumis au limiteur de débit |
| Mise à l'échelle | 0 à 3 réplicas, règle HTTP à 20 requêtes simultanées | idem |

## Révisions

Historique complet, du premier déploiement par `deploy.sh` jusqu'au dernier déploiement continu :

```console
$ az containerapp revision list -g rg-quiz-gwc -n <application> --all -o table
Revision                  Active    Etat     Image                                                                         Creee
------------------------  --------  -------  ----------------------------------------------------------------------------  -------------------------
ca-quiz-backend--91t601e  False     Stopped  quiz-backend:4eaf1123785bfb715c2e21cd91250f126ce4501c  2026-11-26T12:38:33+00:00
ca-quiz-backend--0000001  False     Stopped  quiz-backend:3f5ab0d0e960081f74ca10d4b113621699b6223b  2026-11-26T12:46:37+00:00
ca-quiz-backend--0000002  False     Stopped  quiz-backend:4eaf1123785bfb715c2e21cd91250f126ce4501c  2026-11-26T12:48:54+00:00
ca-quiz-backend--0000003  False     Stopped  quiz-backend:3f5ab0d0e960081f74ca10d4b113621699b6223b  2026-11-26T12:52:01+00:00
ca-quiz-backend--0000004  False     Stopped  quiz-backend:05780a476cbbe32748d63ca3ca59cc14ee104388  2026-11-26T13:03:24+00:00
ca-quiz-backend--0000005  False     Stopped  quiz-backend:1d38574f52cd9a7f316ba4fb6e08f1bb9b336de2  2026-11-26T13:08:33+00:00
ca-quiz-backend--0000006  True      Running  quiz-backend:df88c2cab964e4392f0288588ff8b0516dd52a65  2026-11-26T13:25:15+00:00

Revision                   Active    Etat     Image                                                                          Creee
-------------------------  --------  -------  -----------------------------------------------------------------------------  -------------------------
ca-quiz-frontend--2le2jer  False     Stopped  quiz-frontend:4eaf1123785bfb715c2e21cd91250f126ce4501c  2026-11-26T12:39:39+00:00
ca-quiz-frontend--0000001  False     Stopped  quiz-frontend:3f5ab0d0e960081f74ca10d4b113621699b6223b  2026-11-26T12:46:54+00:00
ca-quiz-frontend--0000002  False     Stopped  quiz-frontend:4eaf1123785bfb715c2e21cd91250f126ce4501c  2026-11-26T12:49:13+00:00
ca-quiz-frontend--0000003  False     Stopped  quiz-frontend:3f5ab0d0e960081f74ca10d4b113621699b6223b  2026-11-26T12:52:20+00:00
ca-quiz-frontend--0000004  False     Stopped  quiz-frontend:05780a476cbbe32748d63ca3ca59cc14ee104388  2026-11-26T13:03:39+00:00
ca-quiz-frontend--0000005  False     Stopped  quiz-frontend:1d38574f52cd9a7f316ba4fb6e08f1bb9b336de2  2026-11-26T13:08:48+00:00
ca-quiz-frontend--0000006  True      Running  quiz-frontend:df88c2cab964e4392f0288588ff8b0516dd52a65  2026-11-26T13:25:31+00:00

```

| Révision | Origine |
| --- | --- |
| `--91t601e` | Création par `deploy.sh` (image `4eaf112`) |
| `--0000001` | CD, PR #11 |
| `--0000002` | Retour en arrière involontaire : relance de `deploy.sh`, qui imposait alors son tag d'image ; corrigé depuis ([J3](../J3/README.md#un-second-passage-ne-change-rien-et-ne-revient-jamais-en-arrière)) |
| `--0000003` | Réparation manuelle, retour à l'image du CD |
| `--0000004` | CD, PR #12 |
| `--0000005` | CD, PR #13 : la **Question** modifiée ([démonstration](../J6/README.md#démonstration-complète--une-question-modifiée-de-la-branche-à-azure)) |
| `--0000006` | CD, PR #14 (dernière révision au moment de la capture) |

En mode révision unique, seule la dernière révision est active ; les précédentes sont arrêtées.

## Journaux des révisions

Extrait du premier démarrage (12:38 à 12:41 UTC) :

```console
$ az containerapp logs show -g rg-quiz-gwc -n ca-quiz-backend --type console --tail 5
2026-11-26T12:41:28.35872 Connecting to the container 'ca-quiz-backend'...
2026-11-26T12:41:28.44691 Successfully Connected to container: 'ca-quiz-backend' [Revision: 'ca-quiz-backend--91t601e', Replica: 'ca-quiz-backend--91t601e-6b759d98bc-56lf6']
2026-11-26T12:38:51.4680058+00:00 F Server running on port 3007

$ az containerapp logs show -g rg-quiz-gwc -n ca-quiz-frontend --type console --tail 6
2026-11-26T12:39:57.3030743+00:00 F /docker-entrypoint.sh: Configuration complete; ready for start up
2026-11-26T12:40:01.848659+00:00 F 104.28.179.x - - [26/Nov/2026:12:40:01 +0000] "GET /health HTTP/1.1" 200 15 "-" "curl/8.7.1" "104.28.179.x"
2026-11-26T12:41:09.2219405+00:00 F 104.28.179.x - - [26/Nov/2026:12:41:09 +0000] "GET /health HTTP/1.1" 200 15 "-" "curl/8.7.1" "104.28.179.x"
2026-11-26T12:41:19.7238453+00:00 F 104.28.179.x - - [26/Nov/2026:12:41:19 +0000] "GET /health HTTP/1.1" 200 15 "-" "curl/8.7.1" "104.28.179.x"
```

Côté frontend, Nginx journalise l'adresse **réelle** du client (masquée ici), et non celle du proxy de la plateforme : la reconstitution de l'adresse client par `real_ip` fonctionne sur Azure ([réseau](../../docs/technique/azure.md#réseau)).

## Santé, redirection HTTPS et backend injoignable depuis Internet

```console
$ curl -i https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/health
HTTP/2 200 
content-type: application/json; charset=utf-8
strict-transport-security: max-age=31536000
{"status":"ok"}

$ curl -sI http://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/                    # HTTP redirigé vers HTTPS
HTTP/1.1 301 Moved Permanently
location: https://ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/

$ curl -s https://ca-quiz-backend.internal.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/health          # backend depuis Internet
Error 404 - This Container App is stopped or does not exist.
HTTP 404

$ curl -s https://ca-quiz-backend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io/health          # backend depuis Internet
Error 404 - This Container App is stopped or does not exist.
HTTP 404
```

- `/health` répond `200 {"status":"ok"}` via le frontend, qui relaie vers `http://ca-quiz-backend` à l'intérieur de l'environnement.
- Une requête HTTP sur le frontend est redirigée en HTTPS (301).
- Le backend, appelé depuis Internet par son nom interne ou public, renvoie la page 404 de la plateforme : il n'est exposé qu'aux applications de l'environnement.
