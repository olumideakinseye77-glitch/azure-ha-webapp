resource "azurerm_resource_group" "main" {
  name     = "rg-olu-ha-webapp"
  location = "UK South"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-olu-ha"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                            = "snet-web"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = ["10.0.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "allow_app_8000" {
  name                        = "Allow-App-8000"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8000"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_public_ip" "lb" {
  name                = "pip-olu-ha-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_lb" "main" {
  name                = "lb-olu-ha"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "fe-olu-ha"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  name            = "be-olu-ha"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_lb_probe" "health" {
  name                = "probe-olu-health"
  loadbalancer_id     = azurerm_lb.main.id
  protocol            = "Http"
  port                = 8000
  request_path        = "/health"
  interval_in_seconds = 5
  probe_threshold     = 1
}

resource "azurerm_lb_rule" "http" {
  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8000
  frontend_ip_configuration_name = "fe-olu-ha"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.health.id
  tcp_reset_enabled              = true
  idle_timeout_in_minutes        = 15
}

resource "azurerm_public_ip" "vm1" {
  name                = "vm-olu-web-01PublicIP"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_network_interface" "vm1" {
  name                = "vm-olu-web-01VMNic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfigvm-olu-web-01"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1.id
    primary                       = true
  }
}

resource "azurerm_public_ip" "vm2" {
  name                = "vm-olu-web-02PublicIP"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["2"]
}

resource "azurerm_network_interface" "vm2" {
  name                = "vm-olu-web-02VMNic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfigvm-olu-web-02"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2.id
    primary                       = true
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "vm1" {
  network_interface_id    = azurerm_network_interface.vm1.id
  ip_configuration_name   = "ipconfigvm-olu-web-01"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vm2" {
  network_interface_id    = azurerm_network_interface.vm2.id
  ip_configuration_name   = "ipconfigvm-olu-web-02"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "vm-olu-web-01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s_v2"
  admin_username      = "azureuser"
  zone                = "1"

  network_interface_ids = [
    azurerm_network_interface.vm1.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6Di8MjaJmOI1gwHKH79srchE+48DElAY4ct+/vme6M8/p2G7MTcbXMkr/1lutHtI8f1vqOfyAmoGoxjF7zmZJxY6zIJDK1Uo8JGyFMSg72dR9BkGL7tI1GnljLPg9jhPF14yoTBkYYK+7cgXHINGXDi5NlAwq18NoGdkG2kzcsOra5eIeKuz2JvxRr4Wj8fJMtE3XjC7EkiYKpgQgXBcz3X3Y79GKS706zD7yPEwZaSAsQZkG27Z6gUqCyc8yvhwU5CcJ/UGqXEkDt5c607hYcPYzZ9PoxFwbk+coFWy6Zf/ZIgtPSwb+Vct0mT1iW4zDr39z6k6wpdMkK75yk97X"
  }

  os_disk {
    name                 = "vm-olu-web-01_OsDisk_1_cb4bc16ece1c474f80349fcb0c521804"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "vm-olu-web-02"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s_v2"
  admin_username      = "azureuser"
  zone                = "2"

  network_interface_ids = [
    azurerm_network_interface.vm2.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6Di8MjaJmOI1gwHKH79srchE+48DElAY4ct+/vme6M8/p2G7MTcbXMkr/1lutHtI8f1vqOfyAmoGoxjF7zmZJxY6zIJDK1Uo8JGyFMSg72dR9BkGL7tI1GnljLPg9jhPF14yoTBkYYK+7cgXHINGXDi5NlAwq18NoGdkG2kzcsOra5eIeKuz2JvxRr4Wj8fJMtE3XjC7EkiYKpgQgXBcz3X3Y79GKS706zD7yPEwZaSAsQZkG27Z6gUqCyc8yvhwU5CcJ/UGqXEkDt5c607hYcPYzZ9PoxFwbk+coFWy6Zf/ZIgtPSwb+Vct0mT1iW4zDr39z6k6wpdMkK75yk97X"
  }

  os_disk {
    name                 = "vm-olu-web-02_OsDisk_1_63b88184497145858e20256506788603"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_log_analytics_workspace" "main" {
  name                         = "law-olu-ha"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  sku                          = "PerGB2018"
  retention_in_days            = 30
  local_authentication_enabled = true
}

resource "azurerm_monitor_data_collection_rule" "main" {
  name                = "dcr-olu-ha"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "lawDestination"
    }
  }

  data_flow {
    streams = [
      "Microsoft-Perf",
      "Microsoft-Syslog"
    ]

    destinations = [
      "lawDestination"
    ]
  }

  data_sources {
    performance_counter {
      name                          = "perf-olu-ha"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60

      counter_specifiers = [
        "\\Processor(*)\\% Processor Time",
        "\\Memory(*)\\Available MBytes Memory",
        "\\Logical Disk(*)\\Free Megabytes"
      ]
    }

    syslog {
      name           = "syslog-olu-ha"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["*"]

      log_levels = [
        "Emergency",
        "Alert",
        "Critical",
        "Error",
        "Warning",
        "Notice",
        "Info"
      ]
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "vm1" {
  name                    = "assoc-olu-vm01"
  target_resource_id      = azurerm_linux_virtual_machine.vm1.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.main.id
}

resource "azurerm_monitor_data_collection_rule_association" "vm2" {
  name                    = "assoc-olu-vm02"
  target_resource_id      = azurerm_linux_virtual_machine.vm2.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.main.id
}

resource "azurerm_virtual_machine_extension" "ama_vm1" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm1.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.45"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

resource "azurerm_virtual_machine_extension" "ama_vm2" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm2.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.45"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}
