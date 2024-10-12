terraform {
  backend "azurerm" {
    storage_account_name = "digiclockinfrastate"
    container_name       = "tfstate"
    key                  = "digiclock.tfstate"
    resource_group_name  = "digiclock-Infra-rg"
  }
}
