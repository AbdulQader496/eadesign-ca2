terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

locals {
  aks_kubernetes_version = (
    var.aks_kubernetes_version == null || trimspace(var.aks_kubernetes_version) == ""
  ) ? null : var.aks_kubernetes_version
}

resource "azurerm_resource_group" "ca2" {
  name     = var.resource_group_name
  location = var.azure_location
}

resource "azurerm_kubernetes_cluster" "ca2" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.ca2.location
  resource_group_name = azurerm_resource_group.ca2.name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = local.aks_kubernetes_version
  sku_tier            = "Free"

  default_node_pool {
    name                = "system"
    node_count          = var.aks_node_count
    vm_size             = var.aks_node_vm_size
    os_disk_size_gb     = var.aks_os_disk_size_gb
    auto_scaling_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  tags = {
    project = "eadesign-ca2"
  }
}
