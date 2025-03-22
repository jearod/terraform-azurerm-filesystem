output "linux_vm_public_ip" {
  description = "Public IP of the Linux VM"
  value       = azurerm_public_ip.linux_pip.ip_address
}

output "windows_vm_public_ip" {
  description = "Public IP of the Windows VM"
  value       = azurerm_public_ip.windows_pip.ip_address
}

output "fileshare_name" {
  description = "Name of the Azure File Share"
  value       = azurerm_storage_share.fileshare.name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.storage.name
}

