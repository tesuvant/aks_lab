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
    AKS_NAME                                 = var.aks_name
    BASTION_NAME                             = "private-vnet-bastion"
    FUNCTIONS_EXTENSION_VERSION              = "~4"
    FUNCTIONS_WORKER_RUNTIME                 = "powershell"
    RESOURCE_GROUP                           = var.rg_name
    SUBSCRIPTION                             = data.azurerm_subscription.this.display_name
    VM_NAME                                  = data.azurerm_virtual_machine.vm.name
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.function_sa.primary_connection_string
    AzureWebJobsStorage                      = azurerm_storage_account.function_sa.primary_connection_string
    WEBSITE_CONTENTSHARE                     = "shutdown-function"
  }

  identity {
    type = "SystemAssigned"
  }
  # checkov:skip=CKV_AZURE_56: auth enabled
  # checkov:skip=CKV_AZURE_70: https only
  # checkov:skip=CKV_AZURE_67: latest http version
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/func/"
  output_path = "${path.module}/function_package.zip"
}

resource "null_resource" "upload_function" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<CMD
az functionapp deployment source config-zip \
  --resource-group ${var.rg_name} \
  --name ${azurerm_windows_function_app.function_app.name} \
  --src ${path.module}/function_package.zip
CMD
  }
}

resource "null_resource" "disable_public_access" {
  triggers = {
    function_app_id = azurerm_windows_function_app.function_app.id
  }

  depends_on = [null_resource.upload_function]

  provisioner "local-exec" {
    command = <<CMD
az functionapp update \
  --resource-group ${var.rg_name} \
  --name ${azurerm_windows_function_app.function_app.name} \
  --set publicNetworkAccess=Disabled
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
  retention_in_days   = "30"
}
