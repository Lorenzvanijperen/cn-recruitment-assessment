resource "random_password" "database_administrator" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "application" {
  name                = "psql-${var.project_name}-${local.environment}-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.environment.name
  location            = data.azurerm_resource_group.environment.location

  administrator_login    = "visitadmin"
  administrator_password = random_password.database_administrator.result
  version                = local.environment_config.database.version
  sku_name               = local.environment_config.database.sku_name
  storage_mb             = local.environment_config.database.storage_mb
  auto_grow_enabled      = true

  backup_retention_days        = local.environment_config.database.backup_retention_days
  geo_redundant_backup_enabled = local.environment_config.database.geo_redundant_backup_enabled
  zone                         = local.environment_config.database.zone

  delegated_subnet_id           = azurerm_subnet.database.id
  private_dns_zone_id           = azurerm_private_dns_zone.database.id
  public_network_access_enabled = false

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  dynamic "high_availability" {
    for_each = local.environment_config.database.high_availability_mode == null ? [] : [local.environment_config.database.high_availability_mode]

    content {
      mode = high_availability.value
    }
  }

  tags = local.resource_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.database]
}

resource "azurerm_postgresql_flexible_server_database" "application" {
  name      = local.environment_config.database.name
  server_id = azurerm_postgresql_flexible_server.application.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_key_vault" "application" {
  name                = "kv-${substr(local.alphanumeric_project_name, 0, 6)}-${local.environment}-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.environment.name
  location            = data.azurerm_resource_group.environment.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = local.environment == "prod"
  soft_delete_retention_days = 7

  public_network_access_enabled = true

  tags = local.resource_tags
}

resource "azurerm_user_assigned_identity" "application" {
  name                = "id-${var.project_name}-${local.environment}-runtime-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.environment.name
  location            = data.azurerm_resource_group.environment.location
  tags                = local.resource_tags
}

resource "azurerm_role_assignment" "operator_key_vault_secrets" {
  scope                = azurerm_key_vault.application.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "runtime_key_vault_secrets" {
  scope                            = azurerm_key_vault.application.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.application.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "time_sleep" "role_assignments" {
  create_duration = "30s"

  depends_on = [
    azurerm_role_assignment.operator_key_vault_secrets,
    azurerm_role_assignment.runtime_key_vault_secrets,
    azurerm_role_assignment.runtime_registry_pull,
  ]
}

locals {
  database_url = "postgresql://visitadmin:${urlencode(random_password.database_administrator.result)}@${azurerm_postgresql_flexible_server.application.fqdn}:5432/${azurerm_postgresql_flexible_server_database.application.name}?sslmode=require"
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  key_vault_id = azurerm_key_vault.application.id
  content_type = "application/x-postgresql-connection-string"
  value        = local.database_url

  tags = local.resource_tags

  depends_on = [time_sleep.role_assignments]
}
