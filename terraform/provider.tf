terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 3.0"  
       resource_provider_registrations = "none"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
}