@description('Name of the underlying project')
param project string = 'prj'

@allowed([
  'Basic'
  'Premium'
  'Standard'
])
@description('Event Hubs namespace SKU option')
param eventHubsNamespacePlan string = 'Basic'

@allowed([
  'Basic'
  'Standard'
])
@description('Event Hubs namespace SKU billing tier')
param eventHubsNamespaceTier string = 'Basic'

@description('Event Hubs throughput units')
param eventHubsNamespaceCapacity int = 1

@description('Virtual Network Address Prefix')
param vnetAddressPrefix string = '10.0.0.0/22'

@description('Function Subnet Address Prefix')
param functionAddressPrefix string = '10.0.0.0/24'

@description('Private Link Subnet Address Prefix')
param privateLinkAddressPrefix string = '10.0.1.0/24'

@description('Number of days to retain data in event hub')
param retentionInDays int = 1

@description('Number of partitions to create in event hub')
param partitionCount int = 2

@description('The id that will be given data owner permission for the Digital Twins resource')
param principalId string

@description('The type of the given principal id')
param principalType string = 'User'

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
@description('Location of to be created resources')
param location string

@description('The SKU to use for the IoT Hub.')
param skuName string = 'S1'

@description('The number of IoT Hub units.')
param skuUnits int = 1

@description('Partitions used for the event stream.')
param d2cPartitions int = 4

var unique = substring(uniqueString(resourceGroup().id), 0, 4)

var digitalTwinsName = '${project}-twins-${unique}'
var eventHubsNamespaceName = '${project}-twinns-${unique}'
var eventHubName = '${project}-twinhub-${unique}'

var logAnalyticsName = '${project}-law-${unique}'
var functionName = '${project}-func-${unique}'
var virtualNetworkName = '${project}-vnet-${unique}'

var privateLinkSubnetName = 'PrivateLinkSubnet'
var functionSubnetName = 'FunctionSubnet'

var iotHubName = '${project}-IoThub-${unique}'
var storageAccountName = '${project}stg${unique}'
var funcStorageAccountName = '${project}fstg${unique}'
var storageEndpoint = '${project}stgep-${unique}'
var storageContainerName = 'results'
var uaminame = '${project}-identity-${unique}'

// create user assigned managed identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: uaminame
  location: location
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: '${storageAccountName}/default/${storageContainerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccount
  ]
}

resource IoTHub 'Microsoft.Devices/IotHubs@2021-07-02' = {
  name: iotHubName
  location: location
  sku: {
    name: skuName
    capacity: skuUnits
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: d2cPartitions
      }
    }
    routing: {
      endpoints: {
        storageContainers: [
          {
            connectionString: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
            containerName: storageContainerName
            fileNameFormat: '{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}'
            batchFrequencyInSeconds: 100
            maxChunkSizeInBytes: 104857600
            encoding: 'JSON'
            name: storageEndpoint
          }
        ]
      }
      routes: [
        {
          name: 'StorageRoute'
          source: 'DeviceMessages'
          condition: 'level="storage"'
          endpointNames: [
            storageEndpoint
          ]
          isEnabled: true
        }
      ]
      fallbackRoute: {
        name: '$fallback'
        source: 'DeviceMessages'
        condition: 'true'
        endpointNames: [
          'events'
        ]
        isEnabled: true
      }
    }
    messagingEndpoints: {
      fileNotifications: {
        lockDurationAsIso8601: 'PT1M'
        ttlAsIso8601: 'PT1H'
        maxDeliveryCount: 10
      }
    }
    enableFileUploadNotifications: false
    cloudToDevice: {
      maxDeliveryCount: 10
      defaultTtlAsIso8601: 'PT1H'
      feedback: {
        lockDurationAsIso8601: 'PT1M'
        ttlAsIso8601: 'PT1H'
        maxDeliveryCount: 10
      }
    }
  }
}

// Creates Digital Twins resource
module digitalTwins 'modules/digitaltwins.bicep' = {
  name: 'digitalTwins'
  params: {
    digitalTwinsName: digitalTwinsName
    location: location
    eventHubName: eventHubName
    eventHubNamespace: eventHubsNamespaceName
  }
  dependsOn: [
    eventHub
  ]
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkLocation: location
    virtualNetworkAddressPrefix: vnetAddressPrefix
    functionSubnetName: functionSubnetName
    functionSubnetPrefix: functionAddressPrefix
    privateLinkSubnetName: privateLinkSubnetName
    privateLinkSubnetPrefix: privateLinkAddressPrefix
  }
}

module privatelink 'modules/privatelink.bicep' = {
  name: 'privatelink'
  params: {
    privateLinkName: 'PrivateLinkToDigitalTwins'
    location: location
    privateLinkServiceResourceId: digitalTwins.outputs.id
    groupId: 'API'
    privateLinkSubnetName: privateLinkSubnetName
    privateDnsZoneName: 'privatelink.digitaltwins.azure.net'
    virtualNetworkResourceName: virtualNetworkName
  }
}

module functionApp 'modules/function-app.bicep' = {
  name: 'functionApp'
  params: {
    functionAppName: functionName
    location: location
    storageAccountName: funcStorageAccountName
    logAnalyticsName: logAnalyticsName
    managedIdentityName: uaminame
    managedIdentityGroup: resourceGroup().name
    digitalTwinsEndpoint: digitalTwins.outputs.endpoint
  }
}

module funcRoleAssignment 'modules/funcroleassignement.bicep' = {
  name: 'funcRoleAssignment'
  params: {
    principalId: functionApp.outputs.functionIdentityPrincipalId
    roleId: 'bcd981a7-7f74-457b-83e1-cceb9e632ffe'
    digitalTwinsInstanceName: digitalTwinsName
  }
  dependsOn: [
    functionApp
    digitalTwins
  ]
}

// Creates Event Hubs namespace and associated event hub
module eventHub 'modules/eventhub.bicep' = {
  name: 'eventHub'
  params: {
    eventHubsNamespaceName: eventHubsNamespaceName
    eventHubsNamespaceCapacity: eventHubsNamespaceCapacity
    eventHubsNamespacePlan: eventHubsNamespacePlan
    eventHubsNamespaceTier: eventHubsNamespaceTier
    eventHubName: eventHubName
    retentionInDays: retentionInDays
    partitionCount: partitionCount
    location: location
  }
}

//Assigns roles to resources
module roleAssignment 'modules/roleassignment.bicep' = {
  name: 'roleAssignment'
  params: {
    principalId: principalId
    principalType: principalType
    digitalTwinsName: digitalTwinsName
    digitalTwinsIdentityPrincipalId: digitalTwins.outputs.digitalTwinsIdentityPrincipalId
    eventHubsNamespaceName: eventHubsNamespaceName
    eventHubName: eventHubName
  }
  dependsOn: [
    digitalTwins
    eventHub
  ]
}
