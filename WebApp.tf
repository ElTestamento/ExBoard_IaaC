# App Service Plan
resource "azurerm_service_plan" "exboard_plan" {
  name                = "exboard-app-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Windows"
  sku_name            = "B1"  # Basic Tier, kann je nach Bedarf angepasst werden
}

# App Service (Web App)
resource "azurerm_windows_web_app" "exboard_webapp" {
  name                = "exboard-webapp-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.exboard_plan.location
  service_plan_id     = azurerm_service_plan.exboard_plan.id

  site_config {
    always_on        = true
    ftps_state       = "FtpsOnly"
    http2_enabled    = true

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    # Fügen Sie hier weitere App-Einstellungen hinzu, falls nötig
  }

  https_only = true
}

# Erzeugt einen zufälligen String für eindeutige Benennung
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# Ausgabe der Web App URL
output "webapp_url" {
  value = "https://${azurerm_windows_web_app.exboard_webapp.default_hostname}"
}