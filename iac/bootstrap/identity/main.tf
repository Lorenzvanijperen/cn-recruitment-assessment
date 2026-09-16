data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}

data "terraform_remote_state" "shared" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-novabank-tfstate-c770945f"
    storage_account_name = "stnovabanktfc770945f"
    container_name       = "shared-state"
    key                  = "shared.tfstate"
    subscription_id      = "a614e95e-6667-4b27-adee-a687db20e46b"
  }
}

locals {
  supported_environments = toset(["dev", "prod"])
  environment            = terraform.workspace

  alphanumeric_project_name = replace(var.project_name, "/[^a-z0-9]/", "")
  generated_suffix          = substr(md5(data.azurerm_client_config.current.subscription_id), 0, 8)
  name_suffix               = coalesce(var.name_suffix, local.generated_suffix)
  state_storage_account_id  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/rg-${var.project_name}-tfstate-${local.name_suffix}/providers/Microsoft.Storage/storageAccounts/st${substr(local.alphanumeric_project_name, 0, 8)}tf${local.name_suffix}"

  identities = {
    ai_inspection = {
      display_name = "${var.project_name}-${local.environment}-ai-inspection-${local.name_suffix}"
      vault_id     = data.terraform_remote_state.shared.outputs.resource_ids.key_vaults.ai_inspection
    }
    deployment = {
      display_name = "${var.project_name}-${local.environment}-deployment-${local.name_suffix}"
      vault_id     = data.terraform_remote_state.shared.outputs.resource_ids.key_vaults.deployment
    }
  }

  deployment_roles = toset([
    "Contributor",
    "Key Vault Secrets Officer",
    "User Access Administrator",
  ])

  inspection_roles = toset([
    "Log Analytics Reader",
    "Reader",
  ])
}

resource "terraform_data" "supported_workspace" {
  lifecycle {
    precondition {
      condition     = contains(local.supported_environments, local.environment)
      error_message = "The identity bootstrap supports only the dev and prod Terraform workspaces."
    }
  }
}

resource "azurerm_resource_group" "environment" {
  name     = "rg-${var.project_name}-${local.environment}-${local.name_suffix}"
  location = var.location
  tags = merge(var.tags, {
    environment = local.environment
  })

  depends_on = [terraform_data.supported_workspace]
}

resource "azuread_application" "identity" {
  for_each = local.identities

  display_name = each.value.display_name
  description  = "Terraform-managed ${replace(each.key, "_", " ")} identity for the ${local.environment} environment."
  owners       = [data.azuread_client_config.current.object_id]

  prevent_duplicate_names = true

  depends_on = [terraform_data.supported_workspace]
}

resource "azuread_service_principal" "identity" {
  for_each = azuread_application.identity

  client_id                    = each.value.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "time_static" "credential_issued_at" {}

resource "azuread_application_password" "identity" {
  for_each = azuread_application.identity

  application_id = each.value.id
  display_name   = "terraform-${local.environment}"
  end_date       = timeadd(time_static.credential_issued_at.rfc3339, var.credential_validity)
}

resource "azurerm_role_assignment" "deployment" {
  for_each = local.deployment_roles

  scope                            = azurerm_resource_group.environment.id
  role_definition_name             = each.value
  principal_id                     = azuread_service_principal.identity["deployment"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "inspection" {
  for_each = local.inspection_roles

  scope                            = azurerm_resource_group.environment.id
  role_definition_name             = each.value
  principal_id                     = azuread_service_principal.identity["ai_inspection"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "deployment_registry_push" {
  scope                            = data.terraform_remote_state.shared.outputs.resource_ids.container_registry
  role_definition_name             = "AcrPush"
  principal_id                     = azuread_service_principal.identity["deployment"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "deployment_registry_roles" {
  scope                            = data.terraform_remote_state.shared.outputs.resource_ids.container_registry
  role_definition_name             = "Role Based Access Control Administrator"
  principal_id                     = azuread_service_principal.identity["deployment"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "deployment_application_state" {
  scope                            = "${local.state_storage_account_id}/blobServices/default/containers/application-state"
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.identity["deployment"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "deployment_shared_state" {
  scope                            = "${local.state_storage_account_id}/blobServices/default/containers/shared-state"
  role_definition_name             = "Storage Blob Data Reader"
  principal_id                     = azuread_service_principal.identity["deployment"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_key_vault_secret" "credentials" {
  for_each = local.identities

  name         = local.environment
  key_vault_id = each.value.vault_id
  content_type = "application/json"
  value = jsonencode({
    client_id       = azuread_application.identity[each.key].client_id
    client_secret   = azuread_application_password.identity[each.key].value
    resource_group  = azurerm_resource_group.environment.name
    subscription_id = data.azurerm_client_config.current.subscription_id
    tenant_id       = data.azurerm_client_config.current.tenant_id
  })

  tags = merge(var.tags, {
    environment = local.environment
    purpose     = each.key
  })
}
