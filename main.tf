terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.31.1"
    }
  }
}

provider "azurerm" {
  features {}
}

#Criar um Grupo de Recursos
resource "azurerm_resource_group" "terraformgroup" {
  name     = "recursosUbuntu"
  location = "Brazil South"
  tags = {
    environment = "Homologacao"
    souce       = "Terraform"
    owner       = "bnyulas, dsantos"
  }
}

# Criar uma Rede Virtual
resource "azurerm_virtual_network" "terraformnetwork" {
  name                = "RedeVirtual"
  address_space       = ["10.0.0.0/16"]
  location            = "Brazil South"
  resource_group_name = azurerm_resource_group.terraformgroup.name

  tags = {
    environment = "Homologacao"
  }
}

# Criar uma Sub Rede Virtual
resource "azurerm_subnet" "terraformsubnet" {
  name                 = "SubRedeVirtual"
  resource_group_name  = azurerm_resource_group.terraformgroup.name
  virtual_network_name = azurerm_virtual_network.terraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Criar um IP Público
resource "azurerm_public_ip" "terraformpublicip" {
  name                = "IPPublico"
  location            = "Brazil South"
  resource_group_name = azurerm_resource_group.terraformgroup.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Homologacao"
  }
}

# Criar um Grupo de Segurança de Rede
resource "azurerm_network_security_group" "terraformnsg" {
  name                = "GrupoSegurancaRede"
  location            = "Brazil South"
  resource_group_name = azurerm_resource_group.terraformgroup.name

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

  tags = {
    environment = "Homologacao"
  }
}

# Criar Placa de Rede Virtual
resource "azurerm_network_interface" "terraformnic" {
  name                = "PlacaRedeVirtual"
  location            = "Brazil South"
  resource_group_name = azurerm_resource_group.terraformgroup.name

  ip_configuration {
    name                          = "IPConfig"
    subnet_id                     = azurerm_subnet.terraformsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.terraformpublicip.id
  }

  tags = {
    environment = "Homologacao"
  }
}

# Conecte o grupo de segurança à interface de rede
resource "azurerm_network_interface_security_group_association" "terraformconnectnet" {
  network_interface_id      = azurerm_network_interface.terraformnic.id
  network_security_group_id = azurerm_network_security_group.terraformnsg.id
}

# Gera um texto aleatório para o nome de conta de armazenamento exclusivo
resource "random_id" "terraformrandomId" {
  keepers = {
    # Gera um novo ID apenas quando um novo grupo de recursos é definido
    resource_group = azurerm_resource_group.terraformgroup.name
  }

  byte_length = 8
}

# Cria uma conta de armazenamento para diagnóstico de inicialização
resource "azurerm_storage_account" "storageaccount" {
  name                     = "diag${random_id.terraformrandomId.hex}"
  resource_group_name      = azurerm_resource_group.terraformgroup.name
  location                 = "Brazil South"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Homologacao"
  }
}

# Cria e exibe uma chave SSH
resource "tls_private_key" "terraform_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
#output "tls_private_key" { value = tls_private_key.terraform_ssh.private_key_pem }

# Cria uma máquina virtual
resource "azurerm_linux_virtual_machine" "terraformvm" {
  name                  = "VMLinux"
  location              = "Brazil South"
  resource_group_name   = azurerm_resource_group.terraformgroup.name
  network_interface_ids = [azurerm_network_interface.terraformnic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "OsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "Ubuntu"
  admin_username                  = "ubuntuUser"
  admin_password                  = "Impac2311!"
  disable_password_authentication = false

  admin_ssh_key {
    username   = "ubuntuUser"
    public_key = tls_private_key.terraform_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
  }

  tags = {
    environment = "Homologacao"
  }

}

# Instala o mySQL
resource "azurerm_mysql_server" "db" {
  name                = "db-mysqlserver"
  location            = "Brazil South"
  resource_group_name = azurerm_resource_group.terraformgroup.name

  administrator_login          = "mysqladmin"
  administrator_login_password = "Abril2804!"

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}