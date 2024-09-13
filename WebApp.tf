# App------------
# Notwendig für das tatsächliche Hosting und die Ausführung von Webanwendungen
# Zentrale Aufgabe: Definiert die Compute-Ressourcen für das Hosting von Webanwendungen
# Hier erscheint der S1 Plan trotz höherer kosten im Vergleich zum B1 Plan sinnvoll, da es um den Transfer von DICOM-Daten
# wie CT und MRT geht, bei 4 oder 5 Patienten pro treffen sind die 10GB eines B1 Plan schnell überschritten
# Höhere Pläne als der S1 plan schein zu teuer
resource "azurerm_service_plan" "exboard_plan" {
  name                = "exboard-app-service-plan"
  resource_group_name = azurerm_resource_group.rg-board.name
  location            = var.location
  os_type             = "Windows"
  sku_name            = "S1"
}

# App Service (Web App)-----------------------------
resource "azurerm_windows_web_app" "exboard_webapp" {
  name                = "exboard-frontend-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg-board.name
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
    "AzureAd:ClientId"                     = "YOUR_CLIENT_ID" # muss im Ernstfall angepasst werden.
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

# Notwendige Insights zum korrekten monitoring
resource "azurerm_application_insights" "exboard_insights" {
  name                = "exboard-insights"
  location            = azurerm_resource_group.rg-board.location
  resource_group_name = azurerm_resource_group.rg-board.name
  application_type    = "web"
}

# Aktualisierte Diagnostic Setting ohne retention_policy
resource "azurerm_monitor_diagnostic_setting" "webapp_logs" {
  name                       = "webapp-logs"
  target_resource_id         = azurerm_windows_web_app.exboard_webapp.id
  storage_account_id         = azurerm_storage_account.diagnostic_logs.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.exboard_logs.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceAuditLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Log Analytics Workspace für erweitertes Logging
resource "azurerm_log_analytics_workspace" "exboard_logs" {
  name                = "exboard-logs"
  location            = azurerm_resource_group.rg-board.location
  resource_group_name = azurerm_resource_group.rg-board.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# erstellt zufälligen String für Bennenung der REssource App Service Plan.
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# Key Vault Access Policy für Web App
resource "azurerm_key_vault_access_policy" "webapp_policy" {
  key_vault_id = azurerm_key_vault.vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_web_app.exboard_webapp.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Separate Storage Management Policy für Aufbewahrung: Zur korrekten Implementierung notwendig
resource "azurerm_storage_management_policy" "log_retention" {
  storage_account_id = azurerm_storage_account.diagnostic_logs.id

  rule {
    name    = "log_retention"
    enabled = true
    filters {
      prefix_match = ["insights-logs-appservicehttplogs", "insights-logs-appserviceauditlogs"]
      blob_types   = ["appendBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}