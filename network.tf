resource "azurerm_virtual_network" "cvm_poc_vnet" {
  name                = "cvm_poc_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
}

resource "azurerm_subnet" "cvm_poc_subnet" {
  name                 = "cvm_poc_subnet"
  resource_group_name  = azurerm_resource_group.cvm_poc_rg.name
  virtual_network_name = azurerm_virtual_network.cvm_poc_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "cvm_poc_pubIP" {
  name                = "cvm_poc_pubIP"
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "cvm_poc_kbs_pubIP" {
  name                = "cvm_poc_kbs_pubIP"
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "cvm_poc_nsg" {
  name                = "cvm_poc_nsg"
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name

  # POC only:
  # Allow inbound SSH traffic from outside to connect to the VM
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "cvm_poc_kbs_nsg" {
  name                = "cvm_poc_kbs_nsg"
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name

  # POC only:
  # Allow inbound SSH traffic from outside to connect to the VM
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "cvm_poc_nic" {
  name                = "cvm_poc_nic"
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cvm_poc_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cvm_poc_pubIP.id
  }
}

resource "azurerm_network_interface" "cvm_poc_kbs_nic" {
  name                = "cvm_poc_kbs_nic"
  location            = azurerm_resource_group.cvm_poc_rg.location
  resource_group_name = azurerm_resource_group.cvm_poc_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cvm_poc_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cvm_poc_kbs_pubIP.id
  }
}

resource "azurerm_network_interface_security_group_association" "cvm_poc_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.cvm_poc_nic.id
  network_security_group_id = azurerm_network_security_group.cvm_poc_nsg.id
}

resource "azurerm_network_interface_security_group_association" "cvm_poc_kbs_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.cvm_poc_kbs_nic.id
  network_security_group_id = azurerm_network_security_group.cvm_poc_kbs_nsg.id
}