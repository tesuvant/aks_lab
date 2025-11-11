terraform {
  required_version = ">= 1.12.0"

  backend "azurerm" {
    use_azuread_auth = true
  }
}

