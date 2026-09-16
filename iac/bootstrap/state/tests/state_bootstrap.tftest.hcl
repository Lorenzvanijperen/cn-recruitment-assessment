mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

run "creates_only_private_state_foundations" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition     = azurerm_storage_account.terraform_state.location == "northeurope"
    error_message = "The default state location must accept new subscriptions while remaining in the EU."
  }

  assert {
    condition     = azurerm_storage_account.terraform_state.account_tier == "Standard"
    error_message = "Terraform state must use a Standard storage account."
  }

  assert {
    condition     = azurerm_storage_account.terraform_state.account_replication_type == "LRS"
    error_message = "Terraform state must use locally redundant storage for this PoC."
  }

  assert {
    condition     = azurerm_storage_account.terraform_state.allow_nested_items_to_be_public == false
    error_message = "Terraform state must not permit public blob access."
  }

  assert {
    condition     = length(azurerm_storage_container.terraform_state) == 3
    error_message = "State bootstrap must create shared, identity, and application state containers."
  }

  assert {
    condition = alltrue([
      for container in azurerm_storage_container.terraform_state :
      container.container_access_type == "private"
    ])
    error_message = "Every Terraform state container must be private."
  }

  assert {
    condition = output.state_container_names == {
      application = "application-state"
      identity    = "identity-state"
      shared      = "shared-state"
    }
    error_message = "State bootstrap must expose the three non-secret backend container names."
  }
}
