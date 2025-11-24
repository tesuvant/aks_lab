data "azurerm_storage_account" "sa" {
  name                = var.storage_account_name
  resource_group_name = var.rg_name
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
  storage_account_name          = var.storage_account_name
  public_network_access_enabled = false
  site_config {}

  # version       = "~4"
  # os_type       = "Windows"
  # runtime_stack = "powershell"

  app_settings = {
    AKS_NAME                 = var.aks_name
    AzureWebJobsStorage      = data.azurerm_storage_account.sa.primary_connection_string
    FUNCTIONS_WORKER_RUNTIME = "powershell"
    RESOURCE_GROUP           = var.rg_name
    VM_NAME                  = data.azurerm_virtual_machine.vm.name
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  identity {
    type = "SystemAssigned"
  }
  # checkov:skip=CKV_AZURE_56: auth enabled
  # checkov:skip=CKV_AZURE_70: https only
  # checkov:skip=CKV_AZURE_67: latest http version
}

resource "azurerm_windows_function_app_slot" "slot" {
  name                          = "production"
  function_app_id               = azurerm_windows_function_app.function_app.id
  public_network_access_enabled = false
  storage_account_name          = var.storage_account_name
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

resource "azurerm_role_assignment" "function_sa_contributor" {
  scope                = data.azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_function_app.function_app.identity[0].principal_id
}
