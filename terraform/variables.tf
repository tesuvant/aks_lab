variable "aks_name" {
  description = "AKS name"
  type        = string
}

variable "aks_subnet_cidr" {
  description = "AKS subnet CIDR"
  type        = string
}

variable "location" {
  description = "Azure region location"
  type        = string
}

variable "rg_name" {
  description = "Name of the resource group"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
}

