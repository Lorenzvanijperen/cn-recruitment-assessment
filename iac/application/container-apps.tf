resource "azurerm_role_assignment" "runtime_registry_pull" {
  scope                            = data.terraform_remote_state.shared.outputs.container_registry.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.application.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_container_app" "api" {
  count = var.deploy_api ? 1 : 0

  name                         = "ca-${var.project_name}-${local.environment}-${local.name_suffix}"
  resource_group_name          = data.azurerm_resource_group.environment.name
  container_app_environment_id = azurerm_container_app_environment.application.id
  revision_mode                = "Single"
  tags                         = local.resource_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.application.id]
  }

  registry {
    server   = data.terraform_remote_state.shared.outputs.container_registry.login_server
    identity = azurerm_user_assigned_identity.application.id
  }

  secret {
    name                = "database-url"
    identity            = azurerm_user_assigned_identity.application.id
    key_vault_secret_id = azurerm_key_vault_secret.database_url.versionless_id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8080
    transport                  = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = local.environment_config.container.min_replicas
    max_replicas = local.environment_config.container.max_replicas

    container {
      name   = "api"
      image  = local.container_image
      cpu    = local.environment_config.container.cpu
      memory = local.environment_config.container.memory
      args   = ["serve"]

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name  = "DEPLOYMENT_ENVIRONMENT"
        value = local.environment
      }

      env {
        name  = "PORT"
        value = "8080"
      }
    }
  }

  lifecycle {
    precondition {
      condition     = startswith(local.container_image, "${data.terraform_remote_state.shared.outputs.container_registry.login_server}/")
      error_message = "image_reference must select an image in the shared Azure Container Registry."
    }
  }

  depends_on = [
    time_sleep.role_assignments,
  ]
}

resource "azurerm_container_app_job" "migrate" {
  name                         = "job-${substr(local.alphanumeric_project_name, 0, 6)}-${local.environment}-${local.name_suffix}"
  resource_group_name          = data.azurerm_resource_group.environment.name
  location                     = data.azurerm_resource_group.environment.location
  container_app_environment_id = azurerm_container_app_environment.application.id
  replica_timeout_in_seconds   = 300
  replica_retry_limit          = 1
  tags                         = local.resource_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.application.id]
  }

  registry {
    server   = data.terraform_remote_state.shared.outputs.container_registry.login_server
    identity = azurerm_user_assigned_identity.application.id
  }

  secret {
    name                = "database-url"
    identity            = azurerm_user_assigned_identity.application.id
    key_vault_secret_id = azurerm_key_vault_secret.database_url.versionless_id
  }

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "migrate"
      image  = local.container_image
      cpu    = local.environment_config.container.cpu
      memory = local.environment_config.container.memory
      args   = ["migrate"]

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
    }
  }

  lifecycle {
    precondition {
      condition     = startswith(local.container_image, "${data.terraform_remote_state.shared.outputs.container_registry.login_server}/")
      error_message = "image_reference must select an image in the shared Azure Container Registry."
    }
  }

  depends_on = [
    time_sleep.role_assignments,
  ]
}
