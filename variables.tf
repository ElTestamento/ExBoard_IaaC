#Variablendefinition sinnvoll für modulares Arbeiten und unendlich erweiterbar
variable "location" {
  type        = string
  default     = "West Europe"
  description = "The default Azure region"
}

variable "DataLocation" {
  type        = string
  default     = "Europe"
  description = "The default datalocation"

}
