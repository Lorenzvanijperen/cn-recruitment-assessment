resource "azurerm_virtual_network" "environment" {
  name                = "vnet-${var.project_name}-${local.environment}-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.environment.name
  location            = data.azurerm_resource_group.environment.location
  address_space       = [local.environment_config.network.address_space]
  tags                = local.resource_tags
}

resource "azurerm_subnet" "container_apps" {
  name                            = "snet-container-apps"
  resource_group_name             = data.azurerm_resource_group.environment.name
  virtual_network_name            = azurerm_virtual_network.environment.name
  address_prefixes                = [local.environment_config.network.container_apps_subnet]
  default_outbound_access_enabled = true

  delegation {
    name = "container-apps"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "database" {
  name                            = "snet-postgresql"
  resource_group_name             = data.azurerm_resource_group.environment.name
  virtual_network_name            = azurerm_virtual_network.environment.name
  address_prefixes                = [local.environment_config.network.database_subnet]
  default_outbound_access_enabled = false

  delegation {
    name = "postgresql"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "database" {
  name                = "${var.project_name}-${local.environment}-${local.name_suffix}.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.environment.name
  tags                = local.resource_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "database" {
  name                  = "link-${var.project_name}-${local.environment}-${local.name_suffix}"
  resource_group_name   = data.azurerm_resource_group.environment.name
  private_dns_zone_name = azurerm_private_dns_zone.database.name
  virtual_network_id    = azurerm_virtual_network.environment.id
  registration_enabled  = false
  tags                  = local.resource_tags
}
