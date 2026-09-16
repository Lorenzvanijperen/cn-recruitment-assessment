mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-novabank-unsupported-test1234"
      location = "northeurope"
    }
  }
}

mock_provider "time" {}

override_data {
  target = data.terraform_remote_state.shared

  values = {
    outputs = {
      container_registry = {
        id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-novabank-shared-test1234/providers/Microsoft.ContainerRegistry/registries/crnovabanktest1234"
        login_server = "crnovabanktest1234.azurecr.io"
        name         = "crnovabanktest1234"
      }
    }
  }
}

run "rejects_an_unsupported_workspace" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  expect_failures = [terraform_data.supported_workspace]
}
