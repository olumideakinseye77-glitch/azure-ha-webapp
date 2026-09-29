terraform {
  required_version = ">= 1.16.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "0be06fbd-8a1c-4544-8855-fcea8dfd8a76"
}
