output "resource_group_name" {
  description = "Resource group containing the Terraform state storage account."
  value       = azurerm_resource_group.terraform_state.name
}

output "storage_account_name" {
  description = "Storage account used by downstream Terraform backends."
  value       = azurerm_storage_account.terraform_state.name
}

output "state_container_names" {
  description = "Container names keyed by the Terraform root that uses them."
  value = {
    for purpose, container in azurerm_storage_container.terraform_state :
    purpose => container.name
  }
}

output "resource_ids" {
  description = "Non-secret IDs of resources managed by the state bootstrap."
  value = {
    resource_group  = azurerm_resource_group.terraform_state.id
    storage_account = azurerm_storage_account.terraform_state.id
    containers = {
      for purpose, container in azurerm_storage_container.terraform_state :
      purpose => container.resource_manager_id
    }
  }
}
