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

data "azurerm_virtual_machine" "vm" {
  name                = "foobar"
  resource_group_name = var.rg_name
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
  site_config {}

  # version       = "~4"
  # os_type       = "Windows"
  # runtime_stack = "powershell"

  app_settings = {
    AKS_NAME                 = var.aks_name
    AzureWebJobsStorage      = azurerm_storage_account.function_sa.primary_connection_string
    FUNCTIONS_WORKER_RUNTIME = "powershell"
    RESOURCE_GROUP           = var.rg_name
    VM_NAME                  = data.azurerm_virtual_machine.vm.name
    WEBSITE_RUN_FROM_PACKAGE = "1"

    vnetContentShareEnabled                  = true
    vnetRouteAllEnabled                      = true
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.function_sa.primary_connection_string
    WEBSITE_CONTENTOVERVNET                  = 1 // Deprecated?
    WEBSITE_CONTENTSHARE                     = "shutdown-function"
    WEBSITE_DNS_SERVER                       = "168.63.129.16"
    WEBSITE_VNET_ROUTE_ALL                   = 1 // Deprecated?
  }

  identity {
    type = "SystemAssigned"
  }
  # checkov:skip=CKV_AZURE_56: auth enabled
  # checkov:skip=CKV_AZURE_70: https only
  # checkov:skip=CKV_AZURE_67: latest http version
}

resource "azurerm_windows_function_app_slot" "slot" {
  name                          = "staging"
  function_app_id               = azurerm_windows_function_app.function_app.id
  public_network_access_enabled = false
  storage_account_name          = azurerm_storage_account.function_sa.name
  site_config {}
  # checkov:skip=CKV_AZURE_56: auth enabled
  # checkov:skip=CKV_AZURE_70: https only
  # checkov:skip=CKV_AZURE_67: latest http version
}

resource "azurerm_function_app_function" "timer_trigger" {
  name            = "TimerTriggerFunction"
  function_app_id = azurerm_windows_function_app.function_app.id

  config_json = <<CONFIG
{
    "bindings": [
        {
            "name": "myTimer",
            "type": "timerTrigger",
            "direction": "in",
            "schedule": "0 0 9 * * *"
        }
    ]
}
CONFIG
}

resource "azurerm_role_assignment" "aks_access" {
  scope                = module.aks_cluster.resource_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_function_app.function_app.identity[0].principal_id

}

resource "azurerm_role_assignment" "vm_access" {
  scope                = data.azurerm_virtual_machine.vm.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_windows_function_app.function_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_sa_storage_account_contributor" {
  scope                = azurerm_storage_account.function_sa.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_windows_function_app.function_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_sa_file_smb_contributor" {
  scope                = azurerm_storage_account.function_sa.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_windows_function_app.function_app.identity[0].principal_id
}


resource "null_resource" "deploy_function" {
  triggers = {
    script_hash = filesha256("${path.module}/func/shutdown/run.ps1")
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ./func
      zip -r ../function_package.zip .
      az functionapp deployment source config-zip \
        --resource-group ${var.rg_name} \
        --name ${azurerm_windows_function_app.function_app.name} \
        --src ../function_package.zip
    EOT
  }
  depends_on = [azurerm_windows_function_app.function_app]
}
