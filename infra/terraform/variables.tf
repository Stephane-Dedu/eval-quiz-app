variable "subscription_id" {
  description = "Abonnement Azure (az account show --query id -o tsv)."
  type        = string
}

variable "location" {
  description = "Région du groupe, du registre, des identités et des journaux."
  type        = string
  default     = "germanywestcentral"
}

variable "environment_location" {
  description = "Région de l'environnement Container Apps. Azure for Students n'en autorise qu'un par abonnement : la vitrine doit utiliser une région libre (ADR 0005)."
  type        = string
  default     = "austriaeast"
}

variable "acr_name" {
  description = "Nom du registre, unique dans tout Azure, sans tiret."
  type        = string
  default     = "crquizsdedutf"
}

variable "deploy_apps" {
  description = "Créer les deux applications. Premier apply à false : le registre doit exister et contenir les images avant les applications."
  type        = bool
  default     = false
}

variable "image_tag" {
  description = "Tag des images à déployer (SHA du commit)."
  type        = string
  default     = ""

  validation {
    condition     = !var.deploy_apps || length(var.image_tag) > 0
    error_message = "image_tag est requis quand deploy_apps vaut true."
  }
}

variable "admin_username" {
  description = "Identifiant de l'Administrateur."
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Mot de passe de l'Administrateur, 12 caractères au moins."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12 && !contains(["admin123", "changeme"], var.admin_password)
    error_message = "admin_password : 12 caractères au moins, valeur par défaut du code interdite."
  }
}

variable "jwt_secret" {
  description = "Secret de signature des jetons, 32 caractères au moins (openssl rand -hex 32)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "jwt_secret : 32 caractères au moins."
  }
}

variable "database_url" {
  description = "URL PostgreSQL externe (Neon), TLS obligatoire. Nulle : backend sans base."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.database_url == null || can(regex("sslmode=(verify-full|require)", var.database_url))
    error_message = "database_url doit imposer TLS (sslmode=verify-full)."
  }
}

variable "resend_api_key" {
  description = "Clé Resend ; une valeur factice suffit, le backend refuse de démarrer sans clé."
  type        = string
  sensitive   = true
  default     = "re_factice_emails_desactives"
}

variable "min_replicas" {
  description = "Réplicas minimum par application (0 : rien n'est facturé au repos)."
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Réplicas maximum par application."
  type        = number
  default     = 3
}

variable "http_concurrency" {
  description = "Requêtes simultanées par réplica avant d'en ajouter un."
  type        = number
  default     = 20
}

variable "budget_amount" {
  description = "Budget mensuel du groupe, dans la devise de l'abonnement."
  type        = number
  default     = 10
}

variable "budget_start_date" {
  description = "Premier jour du mois de départ du budget (fixe, pour ne pas modifier le budget chaque mois)."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}

variable "budget_email" {
  description = "Destinataire des alertes budgétaires."
  type        = string
}

variable "github_oidc_subject_prefix" {
  description = "Préfixe du sujet des jetons OIDC du dépôt, identifiants immuables compris."
  type        = string
  default     = "repo:Stephane-Dedu@105072484/eval-quiz-app@1472861267"
}

variable "github_environment" {
  description = "Environnement GitHub autorisé à se connecter avec l'identité du CD."
  type        = string
  default     = "production-tf"
}
