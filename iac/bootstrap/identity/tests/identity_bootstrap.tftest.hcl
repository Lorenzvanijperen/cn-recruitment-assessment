mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "11111111-1111-1111-1111-111111111111"
      tenant_id = "22222222-2222-2222-2222-222222222222"
    }
  }

  mock_resource "azuread_application" {
    defaults = {
      client_id = "33333333-3333-3333-3333-333333333333"
      id        = "/applications/33333333-3333-3333-3333-333333333333"
    }
  }

  mock_resource "azuread_service_principal" {
    defaults = {
      object_id = "44444444-4444-4444-4444-444444444444"
    }
  }

  mock_resource "azuread_application_password" {
    defaults = {
      value = "redacted-test-credential"
    }
  }
}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-novabank-dev-test1234"
    }
  }
}

override_data {
  target = data.terraform_remote_state.shared

  values = {
    outputs = {
      resource_ids = {
        key_vaults = {
          ai_inspection = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.KeyVault/vaults/kv-ai"
          deployment    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.KeyVault/vaults/kv-deployment"
        }
      }
    }
  }
}

run "creates_one_principal_per_purpose" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition     = length(azuread_application.identity) == 2
    error_message = "Each environment must have exactly one deployment and one AI inspection application."
  }

  assert {
    condition     = length(azuread_service_principal.identity) == 2
    error_message = "Each environment must have exactly one deployment and one AI inspection principal."
  }
}

run "keeps_role_assignments_environment_scoped" {
  command = apply

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition = toset([
      for assignment in azurerm_role_assignment.deployment :
      assignment.role_definition_name
    ]) == toset(["Contributor", "User Access Administrator"])
    error_message = "The deployment principal must be able to deploy and assign roles in its environment."
  }

  assert {
    condition = toset([
      for assignment in azurerm_role_assignment.inspection :
      assignment.role_definition_name
    ]) == toset(["Reader", "Log Analytics Reader"])
    error_message = "The AI inspection principal must have read-only environment roles."
  }

  assert {
    condition = alltrue(concat(
      [
        for assignment in azurerm_role_assignment.deployment :
        assignment.scope == azurerm_resource_group.environment.id
      ],
      [
        for assignment in azurerm_role_assignment.inspection :
        assignment.scope == azurerm_resource_group.environment.id
      ]
    ))
    error_message = "Principal roles must be scoped to the current environment resource group."
  }
}

run "stores_credentials_in_purpose_specific_vaults" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition     = azurerm_key_vault_secret.credentials["deployment"].key_vault_id == data.terraform_remote_state.shared.outputs.resource_ids.key_vaults.deployment
    error_message = "Deployment credentials must be stored in the shared deployment vault."
  }

  assert {
    condition     = azurerm_key_vault_secret.credentials["ai_inspection"].key_vault_id == data.terraform_remote_state.shared.outputs.resource_ids.key_vaults.ai_inspection
    error_message = "AI inspection credentials must be stored in the shared AI inspection vault."
  }
}

run "exposes_only_non_secret_identity_metadata" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition = output.environment == {
      dev  = "dev"
      prod = "prod"
    }[terraform.workspace]
    error_message = "Outputs must identify the selected workspace environment."
  }

  assert {
    condition = nonsensitive(output.principals.deployment.display_name) == {
      dev  = "novabank-dev-deployment-test1234"
      prod = "novabank-prod-deployment-test1234"
    }[terraform.workspace]
    error_message = "Outputs must expose non-secret deployment principal metadata."
  }
}
