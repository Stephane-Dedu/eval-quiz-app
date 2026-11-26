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

```console
$ az containerapp show -g rg-quiz-gwc -n ca-quiz-frontend --query '{…}'
{
  "cpu": 0.25,
  "environnement": "/subscriptions/<abonnement>/resourceGroups/rg-quiz-gwc/providers/Microsoft.App/managedEnvironments/cae-quiz",
  "fqdn": "ca-quiz-frontend.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io",
  "httpAutorise": false,
  "identiteRegistre": "/subscriptions/<abonnement>/resourcegroups/rg-quiz-gwc/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-quiz-pull",
  "identites": "UserAssigned",
  "image": "crquizsdedu.azurecr.io/quiz-frontend:4eaf1123785bfb715c2e21cd91250f126ce4501c",
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
  "sondesDeclarees": null,
  "transport": "Auto"
}

$ az containerapp show -g rg-quiz-gwc -n ca-quiz-backend --query '{…}'
{
  "cpu": 0.25,
  "environnement": "/subscriptions/<abonnement>/resourceGroups/rg-quiz-gwc/providers/Microsoft.App/managedEnvironments/cae-quiz",
  "fqdn": "ca-quiz-backend.internal.blackriver-ff16d83f.belgiumcentral.azurecontainerapps.io",
  "httpAutorise": false,
  "identiteRegistre": "/subscriptions/<abonnement>/resourcegroups/rg-quiz-gwc/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-quiz-pull",
  "identites": "UserAssigned",
  "image": "crquizsdedu.azurecr.io/quiz-backend:4eaf1123785bfb715c2e21cd91250f126ce4501c",
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

```console
$ az containerapp revision list -g rg-quiz-gwc -n <application> -o table
Revision                  Etat     Sante    Replicas    Image
------------------------  -------  -------  ----------  ----------------------------------------------------------------------------
ca-quiz-backend--0000003  Running  Healthy  1           quiz-backend:3f5ab0d0e960081f74ca10d4b113621699b6223b

Revision                   Etat     Sante    Replicas    Image
-------------------------  -------  -------  ----------  -----------------------------------------------------------------------------
ca-quiz-frontend--0000003  Running  Healthy  1           quiz-frontend:3f5ab0d0e960081f74ca10d4b113621699b6223b

```

Historique complet, du premier déploiement par `deploy.sh` jusqu'au déploiement continu, dans [`preuves/J6`](../J6/README.md#j6-b--déploiement-après-fusion).

## Journaux des révisions

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
