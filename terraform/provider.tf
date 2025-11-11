terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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


terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"  # An older version, if a newer version exists
    }
  }
}

provider "null" {}
