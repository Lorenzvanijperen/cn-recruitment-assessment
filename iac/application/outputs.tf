output "environment" {
  description = "Deployment environment selected by the Terraform workspace and its committed configuration."
  value       = local.environment
}

output "deployment_status" {
  description = "Declared deployment status from the committed environment configuration."
  value       = local.environment_config.deployment_status
}

output "application" {
  description = "Non-secret API deployment details."
  value = {
    image = local.container_image
    name  = try(azurerm_container_app.api[0].name, null)
    url   = try("https://${azurerm_container_app.api[0].latest_revision_fqdn}", null)
  }
}

output "database" {
  description = "Non-secret private PostgreSQL details."
  value = {
    database_name = azurerm_postgresql_flexible_server_database.application.name
    fqdn          = azurerm_postgresql_flexible_server.application.fqdn
    server_name   = azurerm_postgresql_flexible_server.application.name
  }
}

output "migration_job" {
  description = "Manual database migration job details."
  value = {
    name                = azurerm_container_app_job.migrate.name
    resource_group_name = azurerm_container_app_job.migrate.resource_group_name
  }
}

output "observability" {
  description = "Per-environment central logging details."
  value = {
    container_app_environment_name = azurerm_container_app_environment.application.name
    log_analytics_workspace_id     = azurerm_log_analytics_workspace.environment.id
    log_analytics_workspace_name   = azurerm_log_analytics_workspace.environment.name
    retention_in_days              = azurerm_log_analytics_workspace.environment.retention_in_days
  }
}

output "database_secret" {
  description = "Non-secret location of the database credential."
  value = {
    key_vault_name = azurerm_key_vault.application.name
    secret_name    = azurerm_key_vault_secret.database_url.name
  }
}
