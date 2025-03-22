# Terraform Azure Infrastructure Deployment

This Terraform project automates the deployment of a basic infrastructure on Microsoft Azure. It includes the creation of virtual networks, subnets, virtual machines (both Linux and Windows), network security groups, storage accounts, and file shares. The project also configures the necessary scripts to mount Azure file shares on both Linux and Windows virtual machines.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Resources Deployed](#resources-deployed)
5. [Variables](#variables)
6. [Usage](#usage)
7. [Outputs](#outputs)
8. [Custom Scripts](#custom-scripts)
9. [Contributing](#contributing)

---

## Overview

This Terraform configuration deploys the following resources in Azure:

- **Virtual Network (VNet)**: A virtual network with a defined address space.
- **Subnet**: A subnet within the virtual network.
- **Public IP Addresses**: Public IPs for both Linux and Windows virtual machines.
- **Network Interfaces (NICs)**: Network interfaces for the virtual machines.
- **Network Security Group (NSG)**: A security group with rules to allow SSH (port 22) and RDP (port 3389) traffic.
- **Storage Account**: A storage account with a file share and a container for scripts.
- **Linux Virtual Machine**: An Ubuntu-based Linux VM with a script to mount the Azure file share.
- **Windows Virtual Machine**: A Windows Server 2019 VM with a script to mount the Azure file share.
- **Custom Script Extensions**: Scripts to automatically mount the Azure file share on both VMs.

---

## Prerequisites

Before using this Terraform project, ensure you have the following:

1. **Azure Account**: An active Azure subscription.
2. **Terraform Installed**: Install Terraform from [here](https://www.terraform.io/downloads.html).
3. **Azure CLI**: Install the Azure CLI from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
4. **Terraform Azure Provider**: Ensure the Azure provider is configured in your Terraform environment.

---

## Project Structure

The project is structured as follows:
├── main.tf # Main Terraform configuration file
├── variables.tf # Input variables for the configuration
├── output.tf # Outputs generated by Terraform
├── .gitignore # Specifies files to ignore in Git
└── README.md # This file

---

## Resources Deployed

The following resources are created by this Terraform configuration:

1. **Virtual Network (VNet)**:
   - Name: `vnet-<resource_group_name>`
   - Address Space: `10.0.0.0/16`

2. **Subnet**:
   - Name: `subnet-<resource_group_name>`
   - Address Prefix: `10.0.1.0/24`

3. **Public IP Addresses**:
   - Linux VM: `linux-pip-<resource_group_name>`
   - Windows VM: `windows-pip-<resource_group_name>`

4. **Network Interfaces (NICs)**:
   - Linux VM: `nic-linux-<resource_group_name>`
   - Windows VM: `nic-windows-<resource_group_name>`

5. **Network Security Group (NSG)**:
   - Name: `nsg-<resource_group_name>`
   - Rules: Allow SSH (port 22) and RDP (port 3389)

6. **Storage Account**:
   - Name: `st<resource_group_name>` (truncated to 24 characters)
   - File Share: `fileshare-<resource_group_name>`
   - Container: `scripts`

7. **Virtual Machines**:
   - Linux VM: `vm-linux-<resource_group_name>` (Ubuntu 18.04-LTS)
   - Windows VM: `vm-windows-<resource_group_name>` (Windows Server 2019)

8. **Custom Scripts**:
   - Linux: Mounts the Azure file share using `cifs-utils`.
   - Windows: Mounts the Azure file share using `New-SmbMapping`.

---

## Variables

The following variables are required to deploy this infrastructure:

| Variable Name           | Description                                      | Default Value |
|-------------------------|--------------------------------------------------|---------------|
| `subscription_id`       | Azure Subscription ID                            | -             |
| `resource_group_name`   | Name of the Azure Resource Group                | -             |
| `location`              | Azure region for deployment                     | -             |
| `linux_username`        | Admin username for the Linux VM                 | -             |
| `linux_password`        | Admin password for the Linux VM                 | -             |
| `windows_username`      | Admin username for the Windows VM               | -             |
| `windows_password`      | Admin password for the Windows VM               | -             |

---

## Usage

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd <repository-folder>

2. **Initialize Terraform**:
    `terraform init`

3. **Review the Plan**:
    `terraform plan -out=tf.plan`

4. **Apply the configuration**:
    `terraform apply "tf.plan"`

5. **Test the infrastructure Configutration**:

    - With the outputs result, gather the linux vm ip, for example:
        ```
        Outputs:
    
        fileshare_name = "fileshare-1-34d44ded-playground-sandbox"
        linux_vm_public_ip = "13.88.97.175"
        storage_account_name = "st134d44dedplaygroundsan"
        windows_vm_public_ip = "13.88.97.210"

    - SSH to linux_vm_public_ip and check the file.txt content :
        ``` 
        ssh username@13.88.97.175
        cd /mnt/azurefiles
        cat file.txt

    - The result should be the following:
        ```
        This is the file content created with windows_vm..

6. **Destroy the infrastructure**(when no longer needed):


## Outputs

The following outputs are generated after applying the Terraform configuration:

- **Linux VM Public IP**: The public IP address of the Linux VM.
- **Windows VM Public IP**: The public IP address of the Windows VM.
- **Storage Account Name**: The name of the created storage account.
- **File Share Name**: The name of the file share.

## Custom Scripts

**Linux VM Script** `(lnx_script.sh)`
- Installs `cifs-utils`.
- Mounts the Azure file share to `/mnt/azurefiles`.

**Windows VM Script** `(win_script.ps1)`
- Mounts the Azure file share to `W:`.
- Creates a sample file `(file.txt)` in the file share.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

- At this point, both vm machines are created and works well, the linux vm is able to connect to the mounted file share, but the windows vm, despite during its configuration creates a file in the `/mnt/azurefiles` path, cannot reach the mounted file share after logged in using `RDP`, it seems that the configuration is not persistent during the run of `win_script.ps`.