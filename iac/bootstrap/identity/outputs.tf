output "environment" {
  description = "Deployment environment selected by the Terraform workspace."
  value       = local.environment
}

output "resource_group" {
  description = "Environment resource-group boundary for application resources and role assignments."
  value = {
    id       = azurerm_resource_group.environment.id
    location = azurerm_resource_group.environment.location
    name     = azurerm_resource_group.environment.name
  }
}

output "principals" {
  description = "Non-secret identity metadata keyed by principal purpose."
  value = {
    for purpose, principal in azuread_service_principal.identity :
    purpose => {
      client_id    = principal.client_id
      display_name = azuread_application.identity[purpose].display_name
      object_id    = principal.object_id
    }
  }
}

output "role_assignments" {
  description = "Environment-scoped role names keyed by principal purpose."
  value = {
    ai_inspection = sort(tolist(local.inspection_roles))
    deployment    = sort(tolist(local.deployment_roles))
    scope         = azurerm_resource_group.environment.id
  }
}

output "credential_secret_names" {
  description = "Non-secret Key Vault secret names keyed by principal purpose."
  value = {
    for purpose, secret in azurerm_key_vault_secret.credentials :
    purpose => secret.name
  }
}
