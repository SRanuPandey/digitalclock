# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-digiclock"
  location = "North Europe"
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
# Public IP for Application Gateway
resource "azurerm_public_ip" "agw_pip" {
  name                = "pip-agw-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
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

resource "azurerm_network_interface_security_group_association" "nisg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Storage Account for the Static Website
resource "azurerm_storage_account" "storage" {
  name                     = "staticwebstorageacct"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  static_website {
    index_document = "index.html"
    error_404_document = "index.html"
  }
}

# Output the static website URL
output "static_website_url" {
  value = azurerm_storage_account.storage.primary_web_endpoint
}

# Web App for hosting static content
resource "azurerm_app_service_plan" "asp" {
  name                = "appserviceplan-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    tier = "Basic"
    size = "B1"
  }
}
resource "azurerm_app_service" "app" {
  name                = "webapp-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
}

# Configure App Service to serve the static files from the storage account
resource "azurerm_storage_blob" "website_zip" {
  name                   = "website.zip"
  storage_account_name    = azurerm_storage_account.storage.name
  storage_container_name  = "$web"
  type                    = "Block"
  source                  = "./static-website.zip"  # Path to your website ZIP file
}

# VM Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "adminuser"
  admin_password      = "mypassword@123"
  disable_password_authentication = false

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

#Dedicated Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]  # Ensure this subnet doesn't overlap with others
}

# Application Gateway
# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-digiclock"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  gateway_ip_configuration {
    name      = "appgw-ip-configuration"
    subnet_id = azurerm_subnet.appgw_subnet.id
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
    priority                   = 100
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
