terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.54"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

