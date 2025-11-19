data "azurerm_storage_account" "sa" {
  name                = var.storage_account_name
  resource_group_name = var.rg_name
}

data "azurerm_linux_virtual_machine" "vm" {
  name                = "foobar"
  resource_group_name = var.rg_name
}

resource "azurerm_app_service_plan" "plan" {
  name                = "finops-function-app-plan"
  location            = var.location
  resource_group_name = var.rg_name
  kind                = "FunctionApp"
  sku_name            = "Y1"
}

resource "azurerm_function_app" "function_app" {
  name                 = "shutdown-function"
  location             = var.location
  resource_group_name  = var.rg_name
  app_service_plan_id  = azurerm_app_service_plan.plan.id
  storage_account_name = var.storage_account_name

  version       = "~4"
  os_type       = "Windows"
  runtime_stack = "powershell"

  app_settings = {
    AKS_NAME                 = var.aks_cluster_name
    AzureWebJobsStorage      = data.azurerm_storage_account.sa.primary_connection_string
    FUNCTIONS_WORKER_RUNTIME = "powershell"
    RESOURCE_GROUP           = var.rg_name
    VM_NAME                  = "foobar"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "aks_access" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_function_app.function_app.identity.principal_id
}

resource "azurerm_role_assignment" "vm_access" {
  scope                = data.azurerm_linux_virtual_machine.vm.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_function_app.function_app.identity.principal_id
}


resource "azurerm_function_app_slot" "slot" {
  name            = "production"
  function_app_id = azurerm_function_app.function.id
  app_settings    = var.app_settings

  # Checkov fixes below
  # checkov:skip=CKV_AZURE_56
  https_only      = true
  site_config {
    http2_enabled = true
  }
}

resource "azurerm_function_app_function" "timer_trigger" {
  name            = "TimerTriggerFunction"
  function_app_id = azurerm_function_app.function.id

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
