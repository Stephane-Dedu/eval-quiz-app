# Secrets Container Apps plutôt que Key Vault

Les secrets du backend (`DATABASE_URL`, `JWT_SECRET`, `ADMIN_PASSWORD`, `RESEND_API_KEY`) sont stockés comme secrets Container Apps, définis par `deploy.sh` depuis les variables d'environnement de l'opérateur. Key Vault offrirait rotation centralisée et audit, mais un coffre supprimé reste réservé de 7 à 90 jours : le cycle destruction puis redéploiement exigé par le sujet échouerait sans purge explicite dans `destroy.sh`. Le sujet ne demande que des secrets ; Key Vault est documenté comme l'étape suivante.
