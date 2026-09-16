resource "azurerm_log_analytics_workspace" "environment" {
  name                = "log-${var.project_name}-${local.environment}-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.environment.name
  location            = data.azurerm_resource_group.environment.location
  sku                 = "PerGB2018"
  retention_in_days   = 365
  daily_quota_gb      = local.environment_config.observability.daily_quota_gb

  internet_ingestion_enabled      = true
  internet_query_enabled          = true
  allow_resource_only_permissions = true

  tags = local.resource_tags
}

resource "azurerm_container_app_environment" "application" {
  name                = "cae-${var.project_name}-${local.environment}-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.environment.name
  location            = data.azurerm_resource_group.environment.location

  infrastructure_subnet_id   = azurerm_subnet.container_apps.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.environment.id
  logs_destination           = "log-analytics"
  public_network_access      = "Enabled"

  tags = local.resource_tags
}
