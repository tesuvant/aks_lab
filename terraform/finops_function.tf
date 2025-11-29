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
  public_network_access_enabled = true
  site_config {
    application_insights_connection_string = azurerm_application_insights.function_app.connection_string
    application_insights_key               = azurerm_application_insights.function_app.instrumentation_key
    application_stack {
      powershell_core_version = 7.4
    }
  }
  app_settings = {
    AKS_NAME                    = var.aks_name
    FUNCTIONS_EXTENSION_VERSION = "~4"
    FUNCTIONS_WORKER_RUNTIME    = "powershell"
    RESOURCE_GROUP              = var.rg_name
    SUBSCRIPTION                = data.azurerm_subscription.this.display_name
    VM_NAME                     = data.azurerm_virtual_machine.vm.name
    # WEBSITE_RUN_FROM_PACKAGE                 = "1"
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.function_sa.primary_connection_string
    AzureWebJobsStorage                      = azurerm_storage_account.function_sa.primary_connection_string
    # vnetContentShareEnabled                  = true
    # vnetRouteAllEnabled                      = true
    # WEBSITE_CONTENTOVERVNET                  = 1 // Deprecated?
    WEBSITE_CONTENTSHARE = "shutdown-function"
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

# resource "azurerm_function_app_function" "timer_trigger" {
#   name            = "Shutdown-AKS-VMs"
#   function_app_id = azurerm_windows_function_app.function_app.id
#   language        = "PowerShell"

#   config_json = jsonencode({
#     "bindings" = [
#       {
#         "direction" = "in"
#         "name"      = "Timer"
#         "schedule" : "0 */5 * * * *"
#         "type" = "timerTrigger"
#       }
#     ]
#   })
# }

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/func/"
  output_path = "${path.module}/function_package.zip"
}

resource "null_resource" "upload_function" {
  # triggers = {
  #   function_app_id = azurerm_windows_function_app.function_app.id
  #   src_hash        = data.archive_file.function.output_sha
  # }
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<CMD
az functionapp deployment source delete \
  --resource-group ${var.rg_name} \
  --name ${azurerm_windows_function_app.function_app.name}
az functionapp deployment source config-zip \
  --resource-group ${var.rg_name} \
  --name ${azurerm_windows_function_app.function_app.name} \
  --src ${path.module}/function_package.zip \
CMD
  }
}

resource "azurerm_role_assignment" "rg_access" {
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



