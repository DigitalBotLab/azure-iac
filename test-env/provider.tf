terraform {
  cloud {
    organization = "digital-bot-lab"

    workspaces {
      name = "azure-iot-terraform"
    }
  }

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.50.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {
    
  }
}