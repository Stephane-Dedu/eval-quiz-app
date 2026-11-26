output "acr_login_server" {
  description = "Registre où publier les images avant le second apply."
  value       = azurerm_container_registry.quiz.login_server
}

output "environment_default_domain" {
  description = "Domaine par défaut de l'environnement Container Apps."
  value       = azapi_resource.environment.output.properties.defaultDomain
}

output "frontend_url" {
  description = "URL publique de l'application."
  value       = var.deploy_apps ? "https://${azurerm_container_app.frontend[0].ingress[0].fqdn}" : null
}

output "ci_client_id" {
  description = "Identifiant client de l'identité du CD (variable AZURE_CLIENT_ID)."
  value       = azurerm_user_assigned_identity.ci.client_id
}
