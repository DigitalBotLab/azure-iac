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


var unique = substring(uniqueString(resourceGroup().id), 0, 4)

var digitalTwinsName = '${project}-twins-${unique}'
var eventHubsNamespaceName = '${project}-twinns-${unique}'
var eventHubName = '${project}-twinhub-${unique}'
var eventGridTopicName = '${project}-egtopic-${unique}'
var functionSubscriptionName = '${project}-funcsub-${unique}'


var logAnalyticsName = '${project}-law-${unique}'
var functionName = '${project}-func-${unique}'
var iotHubName = '${project}-IoThub-${unique}'
var storageAccountName = '${project}stg${unique}'
var funcStorageAccountName = '${project}fstg${unique}'
var storageEndpoint = '${project}stgep-${unique}'


module iotHub 'modules/iothub.bicep' = {
  name: 'iotHub'
  params: {
    location: location
    iotHubName: iotHubName
    storageEndpoint: storageEndpoint
    storageAccountName: storageAccountName
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
    eventGridTopicName: eventGridTopicName
  }
  dependsOn: [
    eventHub
    eventGridTopic
  ]
}

module functionApp 'modules/function-app.bicep' = {
  name: 'functionApp'
  params: {
    functionAppName: functionName
    location: location
    storageAccountName: funcStorageAccountName
    logAnalyticsName: logAnalyticsName
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

module eventGridTopic 'modules/eventgridtopic.bicep' = {
  name: eventGridTopicName
  params: {
    eventGridTopicName: eventGridTopicName
    location: location
  }
}


// resource functionSubscription 'Microsoft.EventGrid/eventSubscriptions@2023-06-01-preview' = {
//   name: functionSubscriptionName
//   properties: {
//     destination: {
//       endpointType: 'AzureFunction'
//       properties: {
//         deliveryAttributeMappings: [
//           {
//             name: 'string'
//             type: 'Static'
//             // For remaining properties, see DeliveryAttributeMapping objects
//           }
//         ]
//         maxEventsPerBatch: 1
//         preferredBatchSizeInKilobytes: 16
//         resourceId: functionApp.outputs.id
//       }
//     }
//   }
// }


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
