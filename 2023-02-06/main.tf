terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.2"
    }
  }

  required_version = ">=1.1.0"
}

provider "azurerm" {
  features {
  }
}

resource "azurerm_resource_group" "exec01-aula-infra" {
  name     = "exec01-aula-infra"
  location = "East US"
}

### VIRTUAL NETWORK
resource "azurerm_virtual_network" "vnet-exec01-aula-infra" {
  name                = "vnet-exec01-aula-infra"
  location            = azurerm_resource_group.exec01-aula-infra.location
  resource_group_name = azurerm_resource_group.exec01-aula-infra.name
  address_space       = ["10.0.0.0/16"]
}

### SUBNET
resource "azurerm_subnet" "sub-exec01-aula-infra" {
  name                 = "sub-exec01-aula-infra"
  resource_group_name  = azurerm_resource_group.exec01-aula-infra.name
  virtual_network_name = azurerm_virtual_network.vnet-exec01-aula-infra.name
  address_prefixes     = ["10.0.1.0/24"]
}

## FIREWALL 
resource "azurerm_network_security_group" "nsg-exec01-aula-infra" {
  name                = "nsg-exec01-aula-infra"
  location            = azurerm_resource_group.exec01-aula-infra.location
  resource_group_name = azurerm_resource_group.exec01-aula-infra.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

## IP PUBLICO 
resource "azurerm_public_ip" "ip-exec01-aula-infra" {
  name                = "ip-exec01-aula-infra"
  resource_group_name = azurerm_resource_group.exec01-aula-infra.name
  location            = azurerm_resource_group.exec01-aula-infra.location
  allocation_method   = "Static"
}


### PLACA DE REDE 
resource "azurerm_network_interface" "nic-exec01-aula-infra" {
  name                = "nic-exec01-aula-infra"
  location            = azurerm_resource_group.exec01-aula-infra.location
  resource_group_name = azurerm_resource_group.exec01-aula-infra.name

  ip_configuration {
    name                          = "nic-internal"
    subnet_id                     = azurerm_subnet.sub-exec01-aula-infra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-exec01-aula-infra.id
  }
}

### VIRTUAL MACHINE CONFIGS 
resource "azurerm_virtual_machine" "vm-exec01-aula-infra" {
  name                  = "vm-exec01-aula-infra"
  location              = azurerm_resource_group.exec01-aula-infra.location
  resource_group_name   = azurerm_resource_group.exec01-aula-infra.name
  network_interface_ids = [azurerm_network_interface.nic-exec01-aula-infra.id]
  vm_size               = "Standard_DS1_v2"


  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "grupo01"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }


}

## INSTALL APACHE
resource "null_resource" "install-apache" {
  connection {
    type     = "ssh"
    host     = azurerm_public_ip.ip-exec01-aula-infra.ip_address
    user     = "grupo01"
    password = "Password1234!"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-exec01-aula-infra
  ]
}