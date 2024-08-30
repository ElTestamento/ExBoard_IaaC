#Ressourcengruppe rg
resource "azurerm_resource_group" "rg" {
  name     = "ExBoard-rg"
  location = var.location
}
#vnet
resource "azurerm_virtual_network" "vnet" {
  name                = "ExBoard-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "ExBoardnsg" {
  name                = "ExBoard-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow_https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Authentifikation------------B2c
resource "azurerm_aadb2c_directory" "b2c" {
  country_code            = "DE"
  data_residency_location = var.DataLocation
  display_name            = "HealthSystemB2C"
  domain_name             = "healthsystemb2c.onmicrosoft.com"
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "PremiumP1"
}

# Health Data Services -----------------------
resource "azurerm_healthcare_workspace" "healthworkspace" {
  name                = "mhhhealthdataworkspace"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# DICOM ------------------------------
resource "azurerm_healthcare_dicom_service" "dicom" {
  name         = "dicomservice"
  workspace_id = azurerm_healthcare_workspace.healthworkspace.id
  location     = azurerm_resource_group.rg.location
}

# Data Lake Storage Gen2 -------------------
resource "azurerm_storage_account" "datalake" {
  name                     = "exboarddatalake"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" #dreimalige redundante Speicherung in einer Region
  is_hns_enabled           = true  #feingranulare Zugriffskontrolle wie von HIPAA gefordert.
  #Azure Storage Account als Data Lake Storage Gen2
}

# Azure Data Factory
resource "azurerm_data_factory" "adf" {
  name                = "exboarddatafactory"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }
}

# Linked Service für das bestehende Data Lake Storage
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "datalake_link" {
  name                 = "LinkedServiceDataLake"
  data_factory_id      = azurerm_data_factory.adf.id
  url                  = azurerm_storage_account.datalake.primary_dfs_endpoint
  use_managed_identity = true
}

# Key Vault für Geheimnisschutz--------------------------------
resource "azurerm_key_vault" "vault" {
  name                       = "exboardvault"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
}

#HIPAA-Policy----------------------------------------
resource "azurerm_storage_management_policy" "datalake_expire" {
  storage_account_id = azurerm_storage_account.datalake.id

  rule {
    name    = "deleteafter30days"
    enabled = true
    filters {
      prefix_match = ["container1/path1"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}

# Logic App
resource "azurerm_logic_app_workflow" "scheduler" {
  name                = "case-scheduler"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Azure Monitor: Überwacht!
resource "azurerm_log_analytics_workspace" "monitor" {
  name                = "healthsystemmonitor"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Blob Storage für PDF Dokumente und ähnliche Datenstrukturen
resource "azurerm_storage_account" "blob_PDF" {
  name                     = "healthsystempdf"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Verfallsdatum für Datenspeicherung: Management Policy für PDF Storage auf 30 Tage begrenzt!
resource "azurerm_storage_management_policy" "blobPDF_lifecycle" {
  storage_account_id = azurerm_storage_account.blob_PDF.id

  rule {
    name    = "deletePDFsAfter30days"
    enabled = true
    filters {
      prefix_match = ["pdfs/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30 # 30 Tage
      }
    }
  }
}

# Azure Communication zum Einbinden von Teams uvm.
resource "azurerm_communication_service" "acs" {
  name                = "exboardacs"
  resource_group_name = azurerm_resource_group.rg.name
  data_location       = var.DataLocation
}

# Azure Cognitive Services: Einbinden einfacher AI-Tools
resource "azurerm_cognitive_account" "cognitive" {
  name                = "health-system-cognitive"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "ComputerVision"
  sku_name            = "S1"
}

resource "azurerm_resource_group_policy_assignment" "hipaa_assignment" {
  name                 = "hipaa-compliance-assignment"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_set_definition.hipaa_compliance.id

  parameters = <<PARAMETERS
{
  "effect": {
    "value": "Audit"
  }
}
PARAMETERS
}