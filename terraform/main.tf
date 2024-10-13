provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-digiclock"
  location = "EastUS"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-digiclock"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnets
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-digiclock"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Network Interface for VM Scale Set
resource "azurerm_network_interface" "nic" {
  name                = "nic-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

   # IP Configuration
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# VM Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "azureuser"
  admin_password      = "Password1234!"  # Ensure strong password

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # Network Interface Configuration for VM Scale Set
  network_interface {
    name    = "nic-configuration"
    primary = true

    ip_configuration {
      name                          = "internal"
      subnet_id                     = azurerm_subnet.subnet.id    
    }
  }

  # OS Disk configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "agw_pip" {
  name                = "pip-agw-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Application Gateway
# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  gateway_ip_configuration {
    name      = "appgw-ip-configuration"
    subnet_id = azurerm_subnet.subnet.id
  }

  frontend_port {
    name = "frontend-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.agw_pip.id
  }

  backend_address_pool {
    name = "backend-pool"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity  = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "frontend-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "backend-http-settings"
  }

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
}


output "public_ip" {
  value = azurerm_public_ip.agw_pip.ip_address
}
