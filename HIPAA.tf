resource "azurerm_policy_definition" "storage_encryption" {
  name         = "enforce-storage-encryption"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Enforce encryption for Storage Accounts"

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Storage/storageAccounts"
      }
    ]
  },
  "then": {
    "effect": "[parameters('effect')]"
  }
}
POLICY_RULE

  parameters = <<PARAMETERS
{
  "effect": {
    "type": "String",
    "defaultValue": "Audit",
    "allowedValues": ["Audit", "Deny", "Disabled"]
  }
}
PARAMETERS
}

resource "azurerm_policy_definition" "app_service_https" {
  name         = "enforce-app-service-https"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Ensure App Services use HTTPS"

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Web/sites"
      },
      {
        "field": "Microsoft.Web/sites/httpsOnly",
        "notEquals": "true"
      }
    ]
  },
  "then": {
    "effect": "[parameters('effect')]"
  }
}
POLICY_RULE

  parameters = <<PARAMETERS
{
  "effect": {
    "type": "String",
    "defaultValue": "Audit",
    "allowedValues": ["Audit", "Deny", "Disabled"]
  }
}
PARAMETERS
}

resource "azurerm_policy_definition" "managed_identity" {
  name         = "enforce-managed-identity"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Enforce use of managed identities"

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Web/sites"
      },
      {
        "field": "identity.type",
        "notContains": "SystemAssigned"
      }
    ]
  },
  "then": {
    "effect": "[parameters('effect')]"
  }
}
POLICY_RULE

  parameters = <<PARAMETERS
{
  "effect": {
    "type": "String",
    "defaultValue": "Audit",
    "allowedValues": ["Audit", "Deny", "Disabled"]
  }
}
PARAMETERS
}
resource "azurerm_policy_set_definition" "hipaa_compliance" {
  name         = "hipaa-compliance-initiative"
  policy_type  = "Custom"
  display_name = "HIPAA Compliance Initiative"

  parameters = <<PARAMETERS
    {
      "effect": {
        "type": "String",
        "defaultValue": "Audit",
        "allowedValues": ["Audit", "Deny", "Disabled"]
      }
    }
PARAMETERS

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.storage_encryption.id
    parameter_values     = <<VALUE
    {
      "effect": {"value": "[parameters('effect')]"}
    }
VALUE
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.app_service_https.id
    parameter_values     = <<VALUE
    {
      "effect": {"value": "[parameters('effect')]"}
    }
VALUE
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.managed_identity.id
    parameter_values     = <<VALUE
    {
      "effect": {"value": "[parameters('effect')]"}
    }
VALUE
  }
}