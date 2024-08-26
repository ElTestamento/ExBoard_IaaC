# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "health-system-rg"
  location = "West Europe"
}

# Azure AD B2C Tenant
resource "azurerm_aadb2c_directory" "b2c" {
  country_code            = "DE"
  data_residency_location = "Europe"
  display_name            = "HealthSystemB2C"
  domain_name             = "healthsystemb2c.onmicrosoft.com"
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "PremiumP1"
}

# Health Data Services Workspace
resource "azurerm_healthcare_workspace" "healthworkspace" {
  name                = "health-data-workspace"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# DICOM Service
resource "azurerm_healthcare_dicom_service" "dicom" {
  name         = "dicom-service"
  workspace_id = azurerm_healthcare_workspace.healthworkspace.id
}

# Data Lake Storage Gen2
resource "azurerm_storage_account" "datalake" {
  name                     = "healthsystemdatalake"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

# Logic App
resource "azurerm_logic_app_workflow" "scheduler" {
  name                = "case-scheduler"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Azure Monitor
resource "azurerm_log_analytics_workspace" "monitor" {
  name                = "health-system-monitor"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
}

# Blob Storage for PDF documents
resource "azurerm_storage_account" "blob" {
  name                     = "healthsystempdf"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Key Vault for secrets management
resource "azurerm_key_vault" "vault" {
  name                       = "health-system-vault"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
}

# Azure Communication Services for video conferencing
resource "azurerm_communication_service" "acs" {
  name                = "health-system-acs"
  resource_group_name = azurerm_resource_group.rg.name
  data_location       = "Europe"
}

# Azure Cognitive Services for AI-based image analysis
resource "azurerm_cognitive_account" "cognitive" {
  name                = "health-system-cognitive"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "ComputerVision"
  sku_name            = "S1"
}