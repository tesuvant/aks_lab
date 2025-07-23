terraform {
  required_version = ">= 1.12.0"

  backend "azurerm" {
    resource_group_name  = "aks"
    storage_account_name = "827be54aaks"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
  }
}

