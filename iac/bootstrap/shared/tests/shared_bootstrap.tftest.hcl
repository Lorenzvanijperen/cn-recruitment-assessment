mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
}

run "creates_shared_registry_and_separate_rbac_vaults" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition     = azurerm_resource_group.shared.location == "northeurope"
    error_message = "Shared resources must default to the same EU region as the state bootstrap."
  }

  assert {
    condition     = azurerm_container_registry.shared.sku == "Basic"
    error_message = "The shared registry must use the Basic SKU."
  }

  assert {
    condition     = azurerm_container_registry.shared.admin_enabled == false
    error_message = "The shared registry must not expose admin credentials."
  }

  assert {
    condition     = length(azurerm_key_vault.credentials) == 2
    error_message = "Shared bootstrap must create separate deployment and AI inspection credential vaults."
  }

  assert {
    condition = alltrue([
      for vault in azurerm_key_vault.credentials :
      vault.rbac_authorization_enabled == true
    ])
    error_message = "Credential vaults must use Azure RBAC authorization."
  }

  assert {
    condition     = length(azurerm_role_assignment.bootstrap_operator_vault_secrets) == 2
    error_message = "The bootstrap operator must be able to store and retrieve credentials in both vaults."
  }

  assert {
    condition = output.key_vault_names == {
      ai_inspection = "kv-novaba-ai-test1234"
      deployment    = "kv-novaba-dep-test1234"
    }
    error_message = "Shared bootstrap must expose only the distinct, non-secret vault names."
  }
}
