terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-novabank-tfstate-c770945f"
    storage_account_name = "stnovabanktfc770945f"
    container_name       = "identity-state"
    key                  = "identity.tfstate"
    subscription_id      = "a614e95e-6667-4b27-adee-a687db20e46b"
  }
}

provider "azuread" {}

provider "azurerm" {
  features {}
}

provider "time" {}
