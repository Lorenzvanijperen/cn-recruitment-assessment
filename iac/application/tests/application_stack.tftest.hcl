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
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-novabank-dev-test1234"
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

run "selects_the_committed_environment_configuration" {
  command = plan

  assert {
    condition = output.environment == {
      dev  = "dev"
      prod = "prod"
    }[terraform.workspace]
    error_message = "The active workspace must select the matching committed environment configuration."
  }

  assert {
    condition = output.deployment_status == {
      dev  = "deployable"
      prod = "defined-not-deployed"
    }[terraform.workspace]
    error_message = "The committed configuration must clearly mark prod as defined but not deployed."
  }
}

run "creates_an_isolated_environment_network" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition = azurerm_virtual_network.environment.resource_group_name == {
      dev  = "rg-novabank-dev-test1234"
      prod = "rg-novabank-prod-test1234"
    }[terraform.workspace]
    error_message = "Application networking must stay in the selected environment resource group."
  }

  assert {
    condition = azurerm_subnet.container_apps.address_prefixes[0] == {
      dev  = "10.20.0.0/23"
      prod = "10.30.0.0/23"
    }[terraform.workspace]
    error_message = "Container Apps must receive the subnet selected by the environment YAML."
  }

  assert {
    condition = azurerm_subnet.database.address_prefixes[0] == {
      dev  = "10.20.2.0/28"
      prod = "10.30.2.0/28"
    }[terraform.workspace]
    error_message = "PostgreSQL must receive a separate subnet selected by the environment YAML."
  }
}

run "keeps_postgresql_private_and_its_credential_in_key_vault" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition = (
      azurerm_postgresql_flexible_server.application.public_network_access_enabled == false &&
      azurerm_postgresql_flexible_server.application.backup_retention_days == {
        dev  = 7
        prod = 35
      }[terraform.workspace] &&
      azurerm_postgresql_flexible_server.application.geo_redundant_backup_enabled == {
        dev  = false
        prod = true
      }[terraform.workspace] &&
      length(azurerm_postgresql_flexible_server.application.high_availability) == {
        dev  = 0
        prod = 1
      }[terraform.workspace]
    )
    error_message = "PostgreSQL must disable public access and use the environment backup policy."
  }

  assert {
    condition = (
      azurerm_key_vault.application.rbac_authorization_enabled == true &&
      azurerm_key_vault_secret.database_url.content_type == "application/x-postgresql-connection-string"
    )
    error_message = "The database credential must be stored in the environment RBAC-enabled Key Vault."
  }
}

run "retains_environment_logs_for_one_year" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition = (
      azurerm_log_analytics_workspace.environment.retention_in_days == 365 &&
      azurerm_log_analytics_workspace.environment.resource_group_name == {
        dev  = "rg-novabank-dev-test1234"
        prod = "rg-novabank-prod-test1234"
      }[terraform.workspace]
    )
    error_message = "Each environment must retain its own logs for 365 days."
  }

  assert {
    condition     = azurerm_container_app_environment.application.logs_destination == "log-analytics"
    error_message = "Container Apps application and platform logs must be collected in Log Analytics."
  }
}

run "defines_the_api_and_manual_migration_job" {
  command = plan

  variables {
    name_suffix = "test1234"
  }

  assert {
    condition = (
      azurerm_container_app.api.revision_mode == "Single" &&
      azurerm_container_app.api.ingress[0].external_enabled == true &&
      azurerm_container_app.api.template[0].min_replicas == {
        dev  = 0
        prod = 2
      }[terraform.workspace] &&
      startswith(
        azurerm_container_app.api.template[0].container[0].image,
        "crnovabanktest1234.azurecr.io/",
      ) &&
      contains(
        [for item in azurerm_container_app.api.template[0].container[0].env : item.name],
        "DATABASE_URL",
      )
    )
    error_message = "The API must expose HTTPS ingress and receive its database URL through a secret."
  }

  assert {
    condition = (
      length(azurerm_container_app_job.migrate.manual_trigger_config) == 1 &&
      azurerm_container_app_job.migrate.template[0].container[0].args[0] == "migrate"
    )
    error_message = "Database migrations must run only through a manually triggered job using the API image."
  }
}
