data "azurerm_client_config" "current" {}

locals {
  alphanumeric_project_name = replace(var.project_name, "/[^a-z0-9]/", "")
  generated_suffix          = substr(md5(data.azurerm_client_config.current.subscription_id), 0, 8)
  name_suffix               = coalesce(var.name_suffix, local.generated_suffix)

  state_containers = {
    application = "application-state"
    identity    = "identity-state"
    shared      = "shared-state"
  }
}

resource "azurerm_resource_group" "terraform_state" {
  name     = "rg-${var.project_name}-tfstate-${local.name_suffix}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "terraform_state" {
  name                     = "st${substr(local.alphanumeric_project_name, 0, 8)}tf${local.name_suffix}"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  tags = var.tags
}

resource "azurerm_storage_container" "terraform_state" {
  for_each = local.state_containers

  name                  = each.value
  storage_account_id    = azurerm_storage_account.terraform_state.id
  container_access_type = "private"
}
