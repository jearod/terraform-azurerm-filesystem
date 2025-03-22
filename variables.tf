variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

################################
# Purpose: Define the variables that will be used in the main configuration file
variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "windows_username" {
  description = "The username for the Windows VM"
  type        = string
}

variable "windows_password" {
  description = "The password for the Windows VM"
  type        = string
}

variable "linux_username" {
  description = "The username for the Linux VM"
  type        = string
}

variable "linux_password" {
  description = "The password for the Linux VM"
  type        = string
}