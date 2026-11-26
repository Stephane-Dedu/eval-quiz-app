# Problèmes connus

Défauts relevés en lisant le code fourni. Le sujet interdit de modifier la logique métier ([ADR 0002](../adr/0002-code-applicatif-fige.md)) : chacun est soit contourné par l'infrastructure, soit documenté ici. La colonne « Traitement » dit lequel.

## Fonctionnement

| Problème | Cause dans le code | Conséquence | Traitement |
| --- | --- | --- | --- |
| **Résultat perdu si une Question expire** | Une Question sans Réponse envoie `userAnswer: null`, alors que `answers.user_answer` est `NOT NULL` | L'insertion échoue, la transaction est annulée : tout le Résultat est perdu (500) | Documenté. Les démonstrations répondent à toutes les Questions |
| **Succès affiché même en cas d'échec** | `main.js` ne vérifie pas `response.ok` après `POST /api/results` | « Résultats envoyés par email » s'affiche après un 500 | Documenté |
| **Plantage si la base est injoignable** | Dans `POST /api/results` et les deux `DELETE`, `await pool.connect()` est hors du `try` ; Express 4 ne capte pas les rejets asynchrones | Rejet non géré : le processus Node s'arrête | Redémarrage automatique (`restart: unless-stopped` en local, Container Apps sur Azure) |
| **Démarrage impossible sans clé Resend** | `new Resend(process.env.RESEND_API_KEY)` au chargement du module | Le backend s'arrête avant d'ouvrir son port ([preuve](../../preuves/J1/diagnostic-demarrage-backend.md)) | Clé factice tant que l'email n'est pas configuré (`.env.example`, `deploy.sh`) |
| **Arrêt lent** | Aucun gestionnaire de SIGTERM ; Node en processus 1 l'ignore | `docker stop` attend 10 s puis tue le processus | tini en processus 1 : arrêt en 0,3 s |
| **Schéma non rejouable** | `CREATE TABLE` sans `IF NOT EXISTS` dans `init.sql` | Rejouer le script échoue | En local, exécuté seulement sur volume vide ; sur Neon, `deploy.sh` vérifie d'abord l'existence des tables |
| **Inscription limitée à 5 par IP et par 15 minutes** | `registrationLimiter` | Des tests répétés finissent en 429 | Documenté ([conteneurisation](conteneurisation.md#problèmes-fréquents)) |
| **Délai de connexion court** | `connectionTimeoutMillis: 2000` | Une base Neon en veille met plus longtemps à répondre au premier appel | Mesuré sur Azure : 1,04 s au premier appel après 8 minutes d'inactivité, contre 0,2 s ensuite. Sous le délai de 2 s, aucun échec ([preuve](../../preuves/J5/README.md#mise-en-veille-de-neon)) |

## Exploitation

| Problème | Cause dans le code | Conséquence | Traitement |
| --- | --- | --- | --- |
| **`/health` soumis au limiteur** | `app.use(generalLimiter)` avant les routes : 100 requêtes par 15 minutes et par IP, `/health` compris | Une sonde HTTP fréquente finit en 429 et fait redémarrer le conteneur | Contrôle de santé Docker toutes les 30 s ; sondes TCP sur Azure |
| **`/health` ne vérifie pas la base** | La route ne fait aucune requête SQL | 200 même base arrêtée | Le test d'intégration passe par une inscription et un Résultat |
| **Nombre de proxys codé en dur** | `trust proxy 2` | Derrière les proxys de Container Apps, tous les visiteurs auraient partagé un seul compteur de limitation ; en local, un `X-Forwarded-For` forgé le contournait | Nginx retrouve l'adresse réelle du client et ne transmet qu'elle ([Azure](azure.md#réseau)) |

## Sécurité

| Problème | Cause dans le code | Conséquence | Traitement |
| --- | --- | --- | --- |
| **Valeurs par défaut faibles** | `ADMIN_PASSWORD` vaut `admin123`, `JWT_SECRET` vaut `change-this-secret` si absents | Connexion administrateur devinable, jetons forgeables | Compose refuse de démarrer sans valeur (`${VAR:?}`) ; `deploy.sh` exige 12 et 32 caractères et refuse les valeurs par défaut |
| **XSS stockée dans l'administration** | `admin.js` insère prénom et email par `innerHTML` | Un prénom piégé exécuterait du code chez l'Administrateur, qui garde son jeton dans `localStorage` | Atténué : la politique de sécurité du contenu interdit tout script en ligne et tout gestionnaire d'événement injecté. Le défaut reste dans le code |
| **Injection de formule dans l'export CSV** | Valeurs non échappées | Une cellule `=…` s'exécute à l'ouverture dans un tableur | Documenté |
| **HTML non échappé dans l'email** | Prénom et textes interpolés dans le gabarit | Contenu arbitraire dans l'email envoyé | Documenté ; emails désactivés (clé factice) |
| **Score calculé par le navigateur** | Le serveur accepte le score envoyé | Un Participant peut déclarer n'importe quel score | Documenté |
| **CORS ouvert** | `cors()` sans option | N'importe quelle origine peut appeler l'API | Sans effet en pratique : le backend n'est joignable que par Nginx, sur la même origine (réseau interne en local, ingress interne sur Azure) |
| **Connexion administrateur sans limitation propre** | Seul le limiteur général s'applique | 100 essais de mot de passe par 15 minutes et par IP | Mot de passe long et aléatoire imposé par `deploy.sh` |
| **Emails en clair dans les journaux** | Échec d'envoi journalisé avec l'adresse | Données personnelles dans les journaux | Documenté ; rétention de 30 jours sur Azure |

## Données

| Problème | Conséquence | Traitement |
| --- | --- | --- |
| **Pas d'unicité sur l'email** : chaque inscription crée une ligne `users` | Une même personne a plusieurs lignes | L'administration regroupe par email ; le [vocabulaire](../../GLOSSARY.md) identifie un **Participant** par son email |
| **Le Sujet n'est pas enregistré** | Impossible de savoir sur quel Sujet porte un Résultat | Documenté |
