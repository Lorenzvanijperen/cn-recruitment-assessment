output "resource_group_name" {
  description = "Name of the shared resource group."
  value       = azurerm_resource_group.shared.name
}

output "container_registry" {
  description = "Non-secret details used by environment application stacks."
  value = {
    id           = azurerm_container_registry.shared.id
    login_server = azurerm_container_registry.shared.login_server
    name         = azurerm_container_registry.shared.name
  }
}

output "key_vault_names" {
  description = "Credential vault names keyed by principal purpose."
  value = {
    for purpose, vault in azurerm_key_vault.credentials :
    purpose => vault.name
  }
}

output "resource_ids" {
  description = "Non-secret IDs of resources managed by the shared bootstrap."
  value = {
    container_registry = azurerm_container_registry.shared.id
    key_vaults = {
      for purpose, vault in azurerm_key_vault.credentials :
      purpose => vault.id
    }
    resource_group = azurerm_resource_group.shared.id
  }
}
