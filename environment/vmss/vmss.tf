terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"  
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "azurerm" {
    resource_group_name   = "RG-infra"
    storage_account_name  = "stdeveustfstate001"
    container_name        = "terraform-state-dev"
    key                   = "terraform.tfstate"
  }
}


provider "azurerm" {
  #use_oidc = true
  features {}
}

provider "random" {}


variable "projectname" {
  #default = "pj"
}

variable "admin_username" {
  #default = "sdvuser"
}
variable "vmss_uniquesuffix" {
  #default = "001"
}
variable "admin_password_length" {
  description = "The length of the generated admin password"
  default     = 20
}

variable "location" {
  default = "eastus"
}

variable "environmentStage" {
  //default = "dev"
}

variable "compute_gallery_name" {
  //default = "sdv_dev_image_gallery_001"
}
variable "IMAGE_NAME"{
  //default = "node-sms-silver-mc-concerto-generalized"
  ///// $image_name="$image_offer`ModelConnect$MCBaseVersion`Concerto$ConcertoVersion"
}

variable "storage_account_type"{
  //default = "Standard_LRS"
}
variable "caching"{
  //default = "ReadWrite"
}
variable "sku"{
  //default = "Standard_B2als_v2"
}
variable "instances"{
  //default = "1"
}

variable "keyvault_name"{
  //default = "sdv-dev-kv-"
}

variable "customerOEMsuffix"{
  default = "sdv"
}

data "azurerm_resource_group" "example" {
  name = "RG-infra"
}

data "azurerm_key_vault" "example" {
  name                = var.keyvault_name 
  resource_group_name = data.azurerm_resource_group.example.name
}

data "azurerm_virtual_network" "example" {
  name                = "vnet-eus-dev-001"
  resource_group_name = data.azurerm_resource_group.example.name
}

data "azurerm_subnet" "internal" {
  name                 = "acr_subnet"
  resource_group_name  = data.azurerm_resource_group.example.name
  virtual_network_name = data.azurerm_virtual_network.example.name
}
//data "azurerm_shared_image_gallery" "example"{
  //    resource_group_name = var.SHARED_RESOURCE_GROUP
    //  name        = var.compute_gallery_name
//}

data "azurerm_shared_image" "all" {
  name                = var.IMAGE_NAME
  resource_group_name = data.azurerm_resource_group.example.name
  gallery_name        = var.compute_gallery_name
}

//data "azurerm_shared_image" "all" {
  //for_each = toset(data.azurerm_shared_image_gallery.example.image_names)

  //name                = each.value
  //resource_group_name = var.SHARED_RESOURCE_GROUP
  //gallery_name        = var.gallery_name
//}
// make it variable - sms
//locals {
  //filtered_images = [
    //for image in values(data.azurerm_shared_image.all) :
    //image
    //if image.name != null && can(regex("${var.IMAGE_NAME}", image.name))    
  //]
//}
//output "filtered_images" {
  //value = local.filtered_images
//}

resource "random_password" "vmss_password" {
  length  = var.admin_password_length
  special = true
}

resource "azurerm_key_vault_secret" "admin_password_secret" {
  name         = "vmss-admin-password-value-vmss-${var.vmss_uniquesuffix}"
  value        = random_password.vmss_password.result
  key_vault_id = data.azurerm_key_vault.example.id
}


resource "random_password" "local_user_password" {
  length  = var.admin_password_length
  special = true
}

resource "azurerm_key_vault_secret" "local_user_password_secret" {
  name         = "local-user-password-value-vmss-${var.vmss_uniquesuffix}"
  value        = random_password.local_user_password.result
  key_vault_id = data.azurerm_key_vault.example.id
}

 resource "azurerm_network_security_group" "example" {
  name                = "${var.customerOEMsuffix}-p-${var.projectname}-${var.environmentStage}-vmssnsg-${var.vmss_uniquesuffix}"
   location            = data.azurerm_resource_group.example.location
   resource_group_name = data.azurerm_resource_group.example.name
 }

resource "azurerm_windows_virtual_machine_scale_set" "example" {
  name                = "${var.customerOEMsuffix}-p-${var.projectname}-${var.environmentStage}-vmss-${var.vmss_uniquesuffix}"
  resource_group_name = data.azurerm_resource_group.example.name
  location            = var.location
  sku                 = var.sku
  instances           = var.instances
  admin_username      = var.admin_username
  //admin_password      = random_password.vmss_password.result  
  admin_password      = azurerm_key_vault_secret.admin_password_secret.value
  computer_name_prefix = "vm"
  secure_boot_enabled = true
  vtpm_enabled = true

  source_image_id = data.azurerm_shared_image.all.id

  os_disk {
    storage_account_type = var.storage_account_type
    caching              = var.caching
  }

  network_interface {
    name    = "${var.customerOEMsuffix}-p-${var.projectname}-${var.environmentStage}-vmssnic-${var.vmss_uniquesuffix}"
    primary = true

    ip_configuration {
      name      = "${var.customerOEMsuffix}${var.projectname}${var.environmentStage}ip${var.vmss_uniquesuffix}"
      primary   = true
      subnet_id = data.azurerm_subnet.internal.id
    }
    # Attach the NSG to the VMSS
    network_security_group_id = azurerm_network_security_group.example.id
  }

 extension {
  name                 = "CustomScriptExtension"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "commandToExecute" : "powershell.exe -ExecutionPolicy Unrestricted -Command \"New-LocalUser -Name Devops_Engineer -Password (ConvertTo-SecureString -AsPlainText '${azurerm_key_vault_secret.local_user_password_secret.value}' -Force) -PasswordNeverExpires:$false; Add-LocalGroupMember -Group 'Remote Desktop Users' -Member Devops_Engineer\""
  //"commandToExecute" : "powershell.exe -ExecutionPolicy Unrestricted -Command \"New-LocalUser -Name TestEngineer -Password (ConvertTo-SecureString -AsPlainText 'Password123' -Force) -PasswordNeverExpires:$false -UserMayChangePassword:$true\""
  })
}

}
