
locals {
    rgname = "azure-iot-windfarm"
    region = "westus3"
}

resource "azurerm_resource_group" "example" {
  name     = local.rgname
  location = local.region
}