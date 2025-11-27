data "azurerm_virtual_machine" "vm" {
  name                = "foobar"
  resource_group_name = var.rg_name
}

data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_subscription" "this" {}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_storage_account" "function_sa" {
  name                     = "func${random_string.suffix.result}"
  location                 = var.location
  resource_group_name      = var.rg_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
}

resource "azurerm_service_plan" "plan" {
  name                = "finops-function-app-plan"
  location            = var.location
  resource_group_name = var.rg_name
  sku_name            = "Y1"
  os_type             = "Windows"
  # checkov:skip=CKV_AZURE_212: using consumption plan
  # checkov:skip=CKV_AZURE_225: zone redundant not important
}

resource "azurerm_windows_function_app" "function_app" {
  name                          = "shutdown-function"
  location                      = var.location
  resource_group_name           = var.rg_name
  service_plan_id               = azurerm_service_plan.plan.id
  storage_account_name          = azurerm_storage_account.function_sa.name
  storage_account_access_key    = azurerm_storage_account.function_sa.primary_access_key
  public_network_access_enabled = false
  site_config {
    application_insights_connection_string = azurerm_application_insights.function_app.connection_string
    application_insights_key               = azurerm_application_insights.function_app.instrumentation_key
    application_stack {
      powershell_core_version = 7
    }
  }
  app_settings = {
    AKS_NAME       = var.aks_name
    RESOURCE_GROUP = var.rg_name
    SUBSCRIPTION   = data.azurerm_subscription.this.display_name
    VM_NAME        = data.azurerm_virtual_machine.vm.name
    # AzureWebJobsStorage      = azurerm_storage_account.function_sa.primary_connection_string
    # FUNCTIONS_WORKER_RUNTIME = "powershell"
    # WEBSITE_RUN_FROM_PACKAGE = "1"
    # vnetContentShareEnabled                  = true
    # vnetRouteAllEnabled                      = true
    # WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.function_sa.primary_connection_string
    # WEBSITE_CONTENTOVERVNET                  = 1 // Deprecated?
    # WEBSITE_CONTENTSHARE                     = "shutdown-function"
    # WEBSITE_DNS_SERVER                       = "168.63.129.16"
    # WEBSITE_VNET_ROUTE_ALL                   = 1 // Deprecated?
  }

  identity {
    type = "SystemAssigned"
  }
  # checkov:skip=CKV_AZURE_56: auth enabled
  # checkov:skip=CKV_AZURE_70: https only
  # checkov:skip=CKV_AZURE_67: latest http version
}

# resource "azurerm_windows_function_app_slot" "slot" {
#   name                          = "staging"
#   function_app_id               = azurerm_windows_function_app.function_app.id
#   public_network_access_enabled = false
#   storage_account_name          = azurerm_storage_account.function_sa.name
#   site_config {}
#   # checkov:skip=CKV_AZURE_56: auth enabled
#   # checkov:skip=CKV_AZURE_70: https only
#   # checkov:skip=CKV_AZURE_67: latest http version
# }

resource "azurerm_function_app_function" "timer_trigger" {
  name            = "Shutdown-AKS-VMs"
  function_app_id = azurerm_windows_function_app.function_app.id
  language        = "PowerShell"

  config_json = jsonencode({
    "bindings" = [
      {
        "direction" = "in"
        "name"      = "Timer"
        "schedule" : "0 */5 * * * *"
        "type" = "timerTrigger"
      }
    ]
  })

  file {
    name    = "requirements.psd1"
    content = <<EOT
@{
    # Authentication and account management
    'Az.Accounts' = '5.*'

    # Networking (for Bastion)
    'Az.Network' = '7.*'

    # Kubernetes Service cluster operations
    'Az.Aks' = '7.*'

    # Virtual machine operations
    'Az.Compute' = '11.*'
}
EOT
  }

  file {
    name    = "run.ps1"
    content = <<EOT
param($Timer)
Set-AzContext -Subscription $env:SUBSCRIPTION

# Stop AKS
try {
    Stop-AzAksCluster -ResourceGroupName $env:RESOURCE_GROUP -Name $env:AKS_NAME -Force -ErrorAction Stop
    Write-Host "AKS cluster stopped successfully"
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Warning "Failed to stop AKS cluster: $errorMessage"
}

# Remove Bastion
try {
    Remove-AzBastion -ResourceGroupName $env:RESOURCE_GROUP -Name $env:BASTION_NAME -Force -ErrorAction Stop
    Write-Host "Bastion deleted"
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Warning "Failed to delete Bastion: $errorMessage"
}

# Stop VM
try {
    Stop-AzVM -ResourceGroupName $env:RESOURCE_GROUP -Name $env:VM_NAME -Force -ErrorAction Stop
    Write-Host "VM stopped successfully"
}
catch {
    Write-Warning "Failed to stop VM: $($_.Exception.Message)"
}
EOT
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_role_assignment" "aks_access" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_function_app.function_app.identity[0].principal_id

}

resource "azurerm_application_insights" "function_app" {
  name                = "shutdown-function-insights"
  location            = var.location
  resource_group_name = var.rg_name
  application_type    = "web"
}
