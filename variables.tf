#Variablendefinition sinnvoll für modulares Arbeiten und unendlich erweiterbar
variable "location" {
  type        = string
  default     = "Germany West Central"
  description = "The default Azure region"
}

variable "DataLocation" {
  # Grundsätzlich gesamt Policy in "azurerm_policy_definition" auf "German West Central" gesetzt.
  # Hier gab es jedoch dauerhaft ein Fehler, so dass hier "Europe gewählt werden musste.
  type        = string
  default     = "Europe"
  description = "The default datalocation"

}

variable "vnet_address_space" {
  description = "Address space for the VNet"
  default     = ["10.0.0.0/24"] # IP Restriktion auf 256! Sicherer!
}