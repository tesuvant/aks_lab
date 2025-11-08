data "azurerm_client_config" "current" {}

resource "azurerm_virtual_network" "vnet" {
  location            = var.location
  name                = "private-vnet"
  resource_group_name = var.rg_name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = [var.aks_subnet_cidr]
  name                 = "default"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "aks-subnet-nsg"
  location            = var.location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "Allow-Node-To-Node"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.aks_subnet_cidr
    destination_address_prefix = var.aks_subnet_cidr
  }

  security_rule {
    name                       = "Allow-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "aks_nsg_ass" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

resource "azurerm_private_dns_zone" "zone" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = var.rg_name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "privatelink-${var.location}-azmk8s-io"
  private_dns_zone_name = azurerm_private_dns_zone.zone.name
  resource_group_name   = var.rg_name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = local.common_tags
}

resource "azurerm_user_assigned_identity" "identity" {
  location            = var.location
  name                = "aks-identity"
  resource_group_name = var.rg_name
  tags                = local.common_tags
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
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-containerservice-managedcluster.git?ref=d63075d111501caf1d2be19639ee0723043a52b0"

  dns_prefix_private_cluster = random_string.dns_prefix.result
  name                       = var.aks_name
  location                   = var.location
  resource_group_name        = var.rg_name

  maintenance_window_auto_upgrade = {
    frequency   = "Weekly"
    interval    = "1"
    day_of_week = "Sunday"
    duration    = 4
    utc_offset  = "+00:00"
    start_time  = "00:00"
    start_date  = "2025-11-08T00:00:00Z"
  }

  default_node_pool = {
    auto_scaling_enabled = false
    name                 = "default"
    node_count           = 2
    vm_size              = "Standard_B2s"
    vnet_subnet_id       = azurerm_subnet.subnet.id
    priority             = "Spot"
    eviction_policy      = "Delete"
    spot_max_price       = "-1"
    node_labels = {
      "pool-type" = "spot"
    }
  }

  azure_active_directory_role_based_access_control = {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.identity.id]
  }

  network_profile = {
    dns_service_ip = "10.10.200.10"
    service_cidr   = "10.10.200.0/24"
    network_plugin = "azure"
  }

  private_cluster_enabled = true
  private_dns_zone_id     = azurerm_private_dns_zone.zone.id
  sku_tier                = "Free"

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.private_dns_zone_contributor]
}
