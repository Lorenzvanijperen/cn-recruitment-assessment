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
  requested_environment_config = try(
    yamldecode(file("${path.module}/${local.environment}.yaml")),
    null,
  )
  environment_config = coalesce(
    local.requested_environment_config,
    yamldecode(file("${path.module}/dev.yaml")),
  )

  alphanumeric_project_name = replace(var.project_name, "/[^a-z0-9]/", "")
  generated_suffix          = substr(md5(data.azurerm_client_config.current.subscription_id), 0, 8)
  name_suffix               = coalesce(var.name_suffix, local.generated_suffix)
  resource_group_name       = "rg-${var.project_name}-${local.environment}-${local.name_suffix}"
  resource_tags = merge(var.tags, {
    environment = local.environment
  })

  container_image = coalesce(
    var.image_reference,
    "${data.terraform_remote_state.shared.outputs.container_registry.login_server}/visit-counter:${local.environment_config.container.image_tag}",
  )
}

resource "terraform_data" "supported_workspace" {
  lifecycle {
    precondition {
      condition = (
        contains(local.supported_environments, local.environment) &&
        try(local.requested_environment_config.environment, null) == local.environment
      )
      error_message = "The application stack supports only workspaces with matching committed dev.yaml or prod.yaml configuration."
    }
  }
}

data "azurerm_resource_group" "environment" {
  name = local.resource_group_name

  depends_on = [terraform_data.supported_workspace]
}
