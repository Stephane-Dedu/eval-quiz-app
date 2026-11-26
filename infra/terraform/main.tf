# Mêmes ressources que scripts/deploy.sh, suffixées « -tf », dans leur propre
# groupe : les deux outils ne gèrent jamais les mêmes ressources (ADR 0001).

locals {
  tags = { projet = "quiz-app", gestion = "terraform" }

  names = {
    resource_group = "rg-quiz-tf-gwc"
    log_workspace  = "log-quiz-tf"
    environment    = "cae-quiz-tf"
    frontend       = "ca-quiz-frontend-tf"
    backend        = "ca-quiz-backend-tf"
    pull_identity  = "id-quiz-tf-pull"
    ci_identity    = "id-quiz-tf-github"
  }

  # Secrets du backend ; la base est facultative.
  backend_secrets = merge(
    {
      "jwt-secret"     = var.jwt_secret
      "admin-password" = var.admin_password
      "resend-api-key" = var.resend_api_key
    },
    var.database_url == null ? {} : { "database-url" = var.database_url },
  )

  backend_secret_env = merge(
    {
      JWT_SECRET     = "jwt-secret"
      ADMIN_PASSWORD = "admin-password"
      RESEND_API_KEY = "resend-api-key"
    },
    var.database_url == null ? {} : { DATABASE_URL = "database-url" },
  )
}

# --- Groupe et budget -----------------------------------------------------------

resource "azurerm_resource_group" "quiz" {
  name     = local.names.resource_group
  location = var.location
  tags     = local.tags
}

resource "azurerm_consumption_budget_resource_group" "quiz" {
  name              = "budget-quiz-tf"
  resource_group_id = azurerm_resource_group.quiz.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = [var.budget_email]
    }
  }
}

# --- Journaux, registre, identités ----------------------------------------------------

resource "azurerm_log_analytics_workspace" "quiz" {
  name                = local.names.log_workspace
  location            = var.location
  resource_group_name = azurerm_resource_group.quiz.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_container_registry" "quiz" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = azurerm_resource_group.quiz.name
  sku                 = "Basic"
  # Pas de compte administrateur partagé : l'accès passe par des identités et des rôles.
  admin_enabled = false
  tags          = local.tags
}

resource "azurerm_user_assigned_identity" "pull" {
  name                = local.names.pull_identity
  location            = var.location
  resource_group_name = azurerm_resource_group.quiz.name
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "ci" {
  name                = local.names.ci_identity
  location            = var.location
  resource_group_name = azurerm_resource_group.quiz.name
  tags                = local.tags
}

# Les applications ne peuvent que lire le registre.
resource "azurerm_role_assignment" "pull_acr" {
  scope                = azurerm_container_registry.quiz.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.pull.principal_id
  principal_type       = "ServicePrincipal"
}

# Le CD peut publier des images et créer des révisions, rien d'autre.
resource "azurerm_role_assignment" "ci_acr" {
  scope                = azurerm_container_registry.quiz.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.ci.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "ci_container_apps" {
  scope                = azurerm_resource_group.quiz.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.ci.principal_id
  principal_type       = "ServicePrincipal"
}

# Exigé pour mettre à jour une application qui utilise l'identité de tirage.
resource "azurerm_role_assignment" "ci_pull_identity" {
  scope                = azurerm_user_assigned_identity.pull.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.ci.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_federated_identity_credential" "github" {
  name                      = "github-${var.github_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "${var.github_oidc_subject_prefix}:environment:${var.github_environment}"
  audience                  = ["api://AzureADTokenExchange"]
}

# --- Environnement Container Apps --------------------------------------------------------

resource "azapi_resource" "environment" {
  type      = "Microsoft.App/managedEnvironments@2026-07-01"
  name      = local.names.environment
  location  = var.environment_location
  parent_id = azurerm_resource_group.quiz.id
  tags      = local.tags

  # Version d'API plus récente que le schéma embarqué par azapi.
  schema_validation_enabled = false

  body = {
    properties = {
      environmentMode          = "WorkloadProfiles"
      workloadProfiles         = [{ name = "Consumption", workloadProfileType = "Consumption" }]
      peerTrafficConfiguration = { encryption = { enabled = true } }
      appLogsConfiguration = {
        destination               = "log-analytics"
        logAnalyticsConfiguration = { customerId = azurerm_log_analytics_workspace.quiz.workspace_id }
      }
    }
  }

  # La clé du workspace ne doit apparaître ni dans le plan ni dans l'état.
  sensitive_body = {
    properties = {
      appLogsConfiguration = {
        logAnalyticsConfiguration = { sharedKey = azurerm_log_analytics_workspace.quiz.primary_shared_key }
      }
    }
  }

  response_export_values = ["properties.defaultDomain"]
}

# --- Applications --------------------------------------------------------------------------

resource "azurerm_container_app" "backend" {
  count = var.deploy_apps ? 1 : 0

  name                         = local.names.backend
  container_app_environment_id = azapi_resource.environment.id
  resource_group_name          = azurerm_resource_group.quiz.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pull.id]
  }

  registry {
    server   = azurerm_container_registry.quiz.login_server
    identity = azurerm_user_assigned_identity.pull.id
  }

  dynamic "secret" {
    for_each = local.backend_secrets
    content {
      name  = secret.key
      value = secret.value
    }
  }

  # Ingress interne : joignable depuis l'environnement uniquement.
  ingress {
    external_enabled = false
    target_port      = 3007
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    http_scale_rule {
      name                = "http"
      concurrent_requests = tostring(var.http_concurrency)
    }

    # Aucune sonde déclarée : Container Apps ajoute des sondes TCP ; /health
    # est soumis au limiteur de débit du backend.
    container {
      name   = "backend"
      image  = "${azurerm_container_registry.quiz.login_server}/quiz-backend:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "ADMIN_USERNAME"
        value = var.admin_username
      }

      dynamic "env" {
        for_each = local.backend_secret_env
        content {
          name        = env.key
          secret_name = env.value
        }
      }
    }
  }

  depends_on = [azurerm_role_assignment.pull_acr]
}

resource "azurerm_container_app" "frontend" {
  count = var.deploy_apps ? 1 : 0

  name                         = local.names.frontend
  container_app_environment_id = azapi_resource.environment.id
  resource_group_name          = azurerm_resource_group.quiz.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pull.id]
  }

  registry {
    server   = azurerm_container_registry.quiz.login_server
    identity = azurerm_user_assigned_identity.pull.id
  }

  # Ingress externe en HTTPS ; HTTP redirigé.
  ingress {
    external_enabled           = true
    target_port                = 8080
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    http_scale_rule {
      name                = "http"
      concurrent_requests = tostring(var.http_concurrency)
    }

    container {
      name   = "frontend"
      image  = "${azurerm_container_registry.quiz.login_server}/quiz-frontend:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      # Le backend, par son nom d'application dans l'environnement.
      env {
        name  = "BACKEND_ORIGIN"
        value = "http://${local.names.backend}"
      }

      # Tout le trafic entrant passe par le proxy de la plateforme.
      env {
        name  = "TRUSTED_PROXY_CIDR"
        value = "0.0.0.0/0"
      }
    }
  }

  depends_on = [azurerm_role_assignment.pull_acr, azurerm_container_app.backend]
}
