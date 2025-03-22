provider "azurerm" {
  features {}
  skip_provider_registration = true
  subscription_id            = var.subscription_id
}

# resource "data.azurerm_resource_group" "rg" {
#   name     = var.resource_group_name
#   location = var.location
# }


data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.resource_group_name}"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-${var.resource_group_name}"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "linux_pip" {
  name                = "linux-pip-${var.resource_group_name}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "windows_pip" {
  name                = "windows-pip-${var.resource_group_name}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "linux_nic" {
  name                = "nic-linux-${var.resource_group_name}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux_pip.id
  }
}

resource "azurerm_network_interface" "windows_nic" {
  name                = "nic-windows-${var.resource_group_name}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows_pip.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.resource_group_name}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_storage_account" "storage" {
  name                     = substr("st${replace(var.resource_group_name, "-", "")}", 0, 24)
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "fileshare" {
  name               = "fileshare-${var.resource_group_name}"
  storage_account_id = azurerm_storage_account.storage.id
  quota              = 10
}

resource "azurerm_storage_container" "storage_container" {
  name               = "scripts"
  storage_account_id = azurerm_storage_account.storage.id
}

data "azurerm_storage_account_sas" "sas" {
  connection_string = azurerm_storage_account.storage.primary_connection_string
  https_only        = true

  start  = timestamp()
  expiry = timeadd(timestamp(), "4h") # Válido por 1 hora

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }
  permissions {
    read    = true
    add     = true
    create  = true
    write   = true
    delete  = true
    list    = true
    process = true
    tag     = true
    filter  = true
    update  = true
  }
}

resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                            = "vm-linux-${substr(var.resource_group_name, 0, 6)}"
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = data.azurerm_resource_group.rg.location
  size                            = "Standard_B1s"
  admin_username                  = var.linux_username
  admin_password                  = var.linux_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.linux_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "local_file" "lnx_script" {
  filename = "lnx_script.sh"
  content  = <<-EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install -y cifs-utils

sudo mkdir -p /mnt/azurefiles
sudo mount -t cifs //${azurerm_storage_account.storage.name}.file.core.windows.net/${azurerm_storage_share.fileshare.name} /mnt/azurefiles -o vers=3.0,username=${azurerm_storage_account.storage.name},password=${azurerm_storage_account.storage.primary_access_key},dir_mode=0777,file_mode=0777,serverino
if mountpoint -q /mnt/azurefiles; then
  echo "Mounted succesfully"
else
  echo "Error: Could not be mounted"
  exit 1
fi
EOT
}

resource "azurerm_storage_blob" "blob_lnx_script" {
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.storage_container.name
  name                   = "lnx_script.sh"
  type                   = "Block"
  source                 = local_file.lnx_script.filename
}

resource "azurerm_virtual_machine_extension" "linux_mount_fileshare" {
  depends_on           = [azurerm_linux_virtual_machine.linux_vm]
  name                 = "mount-fileshare"
  virtual_machine_id   = azurerm_linux_virtual_machine.linux_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
      "fileUris": ["${azurerm_storage_blob.blob_lnx_script.url}${data.azurerm_storage_account_sas.sas.sas}"],
      "commandToExecute": "bash lnx_script.sh"
    }
  SETTINGS
}

resource "azurerm_network_interface_security_group_association" "linux_nic_nsg" {
  network_interface_id      = azurerm_network_interface.linux_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
  depends_on                = [azurerm_network_security_group.nsg]
}

resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                = "vm-windows-${substr(var.resource_group_name, 0, 4)}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.windows_username
  admin_password      = var.windows_password

  network_interface_ids = [
    azurerm_network_interface.windows_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "local_file" "win_script" {
  filename = "win_script.ps1"
  content  = <<-EOT
Start-Transcript -Path "C:\logs\mount_fileshare.log" -Append

Write-Output "Starting the script..."

# create mount point
Write-Output "Creating mount point"
New-Item -ItemType Directory -Path C:\mnt\azurefiles -Force

# Mount the file share
Write-Output "Mounting the file share"
try {
    $smbMapping = New-SmbMapping `
        -LocalPath "W:" `
        -RemotePath "\\${azurerm_storage_account.storage.name}.file.core.windows.net\${azurerm_storage_share.fileshare.name}" `
        -UserName "${azurerm_storage_account.storage.name}" `
        -Password "${azurerm_storage_account.storage.primary_access_key}" `
        -Persistent $true

    Write-Output "Mounted successfully: $($smbMapping.Status)"
} catch {
    Write-Output "Error: Could not mount the file share"
    Write-Output $_.Exception.Message
    exit 1
}
# Check if the file share is mounted
if (Get-SmbMapping -LocalPath "W:" -ErrorAction SilentlyContinue) {
    Write-Output "The file share is mounted."

    # Create a file in the file share
    Write-Output "Creating a file in the file share"
    Set-Content -Path "W:\file.txt" -Value "This is the file content created with ${azurerm_windows_virtual_machine.windows_vm.name}."

    # Check if the file was created
    if (Test-Path "W:\file.txt") {
        Write-Output "The file was created successfully."
        # Read the content of the file
        Write-Output "Reading the content of W:\file.txt"
        $fileContent = Get-Content -Path "W:\file.txt"
        Write-Output $fileContent
    } else {
        Write-Output "Error: the file could not be created."
        exit 1
    }
} else {
    Write-Output "Error: the file share is not mounted."
    exit 1
}

Write-Output "Script finished"
Stop-Transcript
EOT
}

resource "azurerm_storage_blob" "blob_win_script" {
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.storage_container.name
  name                   = "win_script.ps1"
  type                   = "Block"
  source                 = local_file.win_script.filename
}

resource "azurerm_virtual_machine_extension" "windows_mount_fileshare" {
  depends_on           = [azurerm_windows_virtual_machine.windows_vm]
  name                 = "mount-fileshare"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
      "fileUris": ["${azurerm_storage_blob.blob_win_script.url}${data.azurerm_storage_account_sas.sas.sas}"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File win_script.ps1"
    }
  SETTINGS
}

resource "azurerm_network_interface_security_group_association" "windows_nic_nsg" {
  network_interface_id      = azurerm_network_interface.windows_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
  depends_on                = [azurerm_network_security_group.nsg]
}
