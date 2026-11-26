# Code applicatif figé, défauts contournés par l'infrastructure

Le sujet interdit de modifier la logique métier. `backend/server.js`, `main.js`, `public/admin.js`, `database/init.sql` et les fichiers de questions restent donc intacts, sauf la modification d'une question pour la démonstration. Les défauts constatés sont contournés par les conteneurs, les sondes et les scripts, puis décrits dans la section « Problèmes connus » de la documentation technique.

## Conséquences

- Sur Azure, les sondes vérifient le port TCP au lieu d'appeler `/health`, car `/health` est soumis au limiteur de 100 requêtes par 15 minutes.
- Les conteneurs tournent avec un processus init pour que l'arrêt (SIGTERM) soit propagé au processus Node, qui ne le gère pas.
- Une clé Resend factice est fournie quand l'envoi d'email n'est pas configuré, car le backend refuse de démarrer sans clé.
- `deploy.sh` refuse de déployer sans mot de passe administrateur ni secret JWT explicites, car le code a des valeurs par défaut faibles.
- Le schéma n'est appliqué que si les tables n'existent pas encore, car `init.sql` n'est pas rejouable.
- Les bugs qui restent visibles (résultat perdu quand une question expire, plantage si la base est injoignable, XSS dans la page d'administration) sont documentés, pas corrigés.
