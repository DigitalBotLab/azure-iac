@description('Name of new Digital Twin resource name')
param digitalTwinsName string

@allowed([
  'westcentralus'
  'westus2'
  'westus3'
  'northeurope'
  'australiaeast'
  'westeurope'
  'eastus'
  'southcentralus'
  'southeastasia'
  'uksouth'
  'eastus2'
])
@description('Location of to be created resource')
param location string


@description('User Managed Identity Name to use')
param managedIdentityName string

@description('User Managed Identity Resource Group')
param managedIdentityGroup string

// get user assigned managed identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
  scope: resourceGroup(managedIdentityGroup)
}

// Creates Digital Twins instance
resource digitalTwins 'Microsoft.DigitalTwins/digitalTwinsInstances@2022-10-31' = {
  name: digitalTwinsName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
}

output id string = digitalTwins.id
output endpoint string = digitalTwins.properties.hostName
