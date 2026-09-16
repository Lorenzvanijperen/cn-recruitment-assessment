terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-novabank-tfstate-c770945f"
    storage_account_name = "stnovabanktfc770945f"
    container_name       = "shared-state"
    key                  = "shared.tfstate"
    subscription_id      = "a614e95e-6667-4b27-adee-a687db20e46b"
  }
}

provider "azurerm" {
  features {}
}
