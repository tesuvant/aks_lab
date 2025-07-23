data "azurerm_client_config" "current" {}

resource "azurerm_virtual_network" "vnet" {
  location            = var.location
  name                = "private-vnet"
  resource_group_name = var.rg_name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "aks-subnet-nsg"
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_subnet" "subnet" {
  address_prefixes          = ["10.1.0.0/24"]
  name                      = "default"
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
  resource_group_name       = var.rg_name
  virtual_network_name      = azurerm_virtual_network.vnet.name
}

resource "azurerm_private_dns_zone" "zone" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = var.rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "privatelink-${var.location}-azmk8s-io"
  private_dns_zone_name = azurerm_private_dns_zone.zone.name
  resource_group_name   = var.rg_name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_user_assigned_identity" "identity" {
  location            = azurerm_resource_group.this.location
  name                = "aks-identity"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "private_dns_zone_contributor" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  scope                = azurerm_private_dns_zone.zone.id
  role_definition_name = "Private DNS Zone Contributor"
}

resource "random_string" "dns_prefix" {
  length  = 10    # Set the length of the string
  lower   = true  # Use lowercase letters
  numeric = false # Include numbers
  special = false # No special characters
  upper   = false # No uppercase letters
}

module "aks_cluster" {
  source  = "Azure/containerservice/azurerm"
  version = "0.2.7"

  dns_prefix_private_cluster = random_string.dns_prefix.result
  name                       = var.aks_name
  location                   = var.location
  resource_group_name        = var.rg_name

  default_node_pool = {
    auto_scaling_enabled = false
    name                 = "default"
    node_count           = 1
    vm_size              = "Standard_DS2_v2"
    vnet_subnet_id       = azurerm_subnet.subnet.id
  }

  azure_active_directory_role_based_access_control = {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  managed_identities = {
    system_assigned = true
  }

  network_profile = {
    dns_service_ip = "10.10.200.10"
    service_cidr   = "10.10.200.0/24"
    network_plugin = "azure"
  }

  private_cluster_enabled = true
  private_dns_zone_id     = azurerm_private_dns_zone.zone.id
  sku_tier                = "Standard"

  depends_on = [azurerm_role_assignment.private_dns_zone_contributor]
}
