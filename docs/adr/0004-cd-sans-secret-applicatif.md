# Le CD ne détient aucun secret applicatif

GitHub ne stocke aucun secret de l'application. Après une fusion, le CD se connecte à Azure par OIDC avec l'identité `id-quiz-github`, pousse les images taguées par commit, puis remplace l'image des deux Container Apps. `scripts/deploy.sh`, lancé par l'opérateur, reste le seul à créer l'infrastructure, définir les secrets et initialiser le schéma. L'identité du CD ne peut que pousser dans le registre et mettre à jour les deux applications du groupe de ressources : un workflow compromis pourrait publier une image, mais jamais lire l'URL de la base.

## Options écartées

- **Exécuter tout `deploy.sh` dans le CD** : il faudrait copier dans GitHub l'URL PostgreSQL, le secret JWT et le mot de passe administrateur, et donner à l'identité le rôle Contributor.
