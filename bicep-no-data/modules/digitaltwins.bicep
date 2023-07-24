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

@description('Name of existing Event Hub to connect and Endpoint to')
param eventHubName string

@description('Name of existing Event Hub to connect and Endpoint to')
param eventHubNamespace string

@description('Name of existing Event Grid Topic to connect and Endpoint to')
param eventGridTopicName string


// Creates Event Hubs namespace
resource eventHubsNamespace 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: eventHubNamespace  
 }

resource eventGridTopic 'Microsoft.EventGrid/topics@2020-06-01' existing = {
  name: eventGridTopicName
}

// Creates Digital Twins instance
resource digitalTwins 'Microsoft.DigitalTwins/digitalTwinsInstances@2022-10-31' = {
  name: digitalTwinsName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

//Endpoint for a Client to listen to Updates
resource clientEndpoint 'Microsoft.DigitalTwins/digitalTwinsInstances/endpoints@2022-10-31' = {
  name: 'ClientEndpoint01'
  parent: digitalTwins
  properties: {
    authenticationType: 'IdentityBased'
    endpointType: 'EventHub'   
    endpointUri: 'sb://${eventHubsNamespace.name}.servicebus.windows.net'
    entityPath: eventHubName
  }
}

//Endpoint to listen to Telemetry Events
resource twinEndpoint 'Microsoft.DigitalTwins/digitalTwinsInstances/endpoints@2022-10-31' = {
  name: 'TelemetryEndpoint01'
  parent: digitalTwins
  properties: {
    authenticationType: 'IdentityBased'
    endpointType: 'EventGrid'   
    TopicEndpoint: eventGridTopicName
    accessKey1: eventGridTopic.listKeys().key1
  }
}


output id string = digitalTwins.id
output endpoint string = digitalTwins.properties.hostName

output digitalTwinsIdentityPrincipalId string = digitalTwins.identity.principalId
output digitalTwinsIdentityTenantId string = digitalTwins.identity.tenantId
