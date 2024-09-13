# Azure provider von Terraform wird hier definiert: in Quelle und Version
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "1e0b0fa8-47e9-4f33-88c8-b09d4afe64a3"
}

data "azurerm_client_config" "current" {}