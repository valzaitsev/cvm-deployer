terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Fetch the Azure CLI login context to:
# 1) Retrieve the tenant data. Used in Azure Key Vault section below
# 2) Get our principal id to get the role assigned for the key generation
data "azurerm_client_config" "current" {}

# Suffix to add to the Key Vault name to ensure uniqueness
resource "random_id" "suffix" {
  byte_length = 4
}

# Create a resource group
# Location is Central US, as quota for the NCC VM was approved there.
# Location from here is referenced in other objects
resource "azurerm_resource_group" "cvm_poc_rg" {
  name     = "cvm_poc_rg"
  location = "centralus"
}
