data "azurerm_client_config" "current" {}

locals {
  alphanumeric_project_name = replace(var.project_name, "/[^a-z0-9]/", "")
  generated_suffix          = substr(md5(data.azurerm_client_config.current.subscription_id), 0, 8)
  name_suffix               = coalesce(var.name_suffix, local.generated_suffix)

  credential_vault_names = {
    ai_inspection = "kv-${substr(local.alphanumeric_project_name, 0, 6)}-ai-${local.name_suffix}"
    deployment    = "kv-${substr(local.alphanumeric_project_name, 0, 6)}-dep-${local.name_suffix}"
  }
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-${var.project_name}-shared-${local.name_suffix}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_registry" "shared" {
  name                = "cr${substr(local.alphanumeric_project_name, 0, 8)}${local.name_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Basic"
  admin_enabled       = false

  public_network_access_enabled = true

  tags = var.tags
}

resource "azurerm_key_vault" "credentials" {
  for_each = local.credential_vault_names

  name                = each.value
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = merge(var.tags, {
    credential-purpose = each.key
  })
}

resource "azurerm_role_assignment" "bootstrap_operator_vault_secrets" {
  for_each = azurerm_key_vault.credentials

  scope                = each.value.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
