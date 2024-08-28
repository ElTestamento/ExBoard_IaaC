# App Service Plan
resource "azurerm_service_plan" "exboard_plan" {
  name                = "exboard-app-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "northeurope"
  os_type             = "Windows"
  sku_name            = "S1" # Premium v2 tier for better performance and scaling
}

# App Service (Web App)
resource "azurerm_windows_web_app" "exboard_webapp" {
  name                = "exboard-frontend-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.exboard_plan.location
  service_plan_id     = azurerm_service_plan.exboard_plan.id

  site_config {
    always_on     = true
    ftps_state    = "FtpsOnly"
    http2_enabled = true

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"             = "1"
    "AzureAd:Instance"                     = "https://login.microsoftonline.com/"
    "AzureAd:Domain"                       = "healthsystemb2c.onmicrosoft.com"
    "AzureAd:TenantId"                     = azurerm_aadb2c_directory.b2c.tenant_id
    "AzureAd:ClientId"                     = "YOUR_CLIENT_ID" # Replace with actual Client ID
    "AzureAd:CallbackPath"                 = "/signin-oidc"
    "HealthDataApi:BaseUrl"                = "https://${azurerm_healthcare_workspace.healthworkspace.name}.azurehealthcareapis.com"
    "Storage:ConnectionString"             = azurerm_storage_account.datalake.primary_connection_string
    "KeyVault:Url"                         = azurerm_key_vault.vault.vault_uri
    "ApplicationInsights:ConnectionString" = azurerm_application_insights.exboard_insights.connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  https_only = true
}

# Application Insights for monitoring
resource "azurerm_application_insights" "exboard_insights" {
  name                = "exboard-insights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

# Random string for unique naming
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# Key Vault Access Policy for Web App
resource "azurerm_key_vault_access_policy" "webapp_policy" {
  key_vault_id = azurerm_key_vault.vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_web_app.exboard_webapp.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Output the Web App URL
output "webapp_url" {
  value = "https://${azurerm_windows_web_app.exboard_webapp.default_hostname}"
}