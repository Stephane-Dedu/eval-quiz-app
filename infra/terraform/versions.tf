terraform {
  required_version = "~> 1.17"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.15"
    }
    # azapi appelle directement l'API Azure : il sert à l'environnement Container
    # Apps, dont le mode (WorkloadProfiles) n'est pas exposé par azurerm (ADR 0005).
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.14"
    }
  }

  # État local : la vitrine est prouvée par un apply puis un destroy ponctuels.
  # En usage réel, l'état irait dans un compte de stockage Azure, chiffré,
  # verrouillé pendant chaque opération et accessible par Entra ID uniquement :
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstatequiz"
  #   container_name       = "tfstate"
  #   key                  = "quiz.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {}
