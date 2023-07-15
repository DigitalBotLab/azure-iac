@description('Name of Event Hubs namespace')
param eventHubsNamespaceName string

@description('Name given to event hub')
param eventHubName string


@description('Number of days to retain data in event hub')
param retentionInDays int

@description('Number of partitions to create in event hub')
param partitionCount int

// Creates Event Hubs namespace
resource eventHubsNamespace 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: eventHubsNamespaceName
}

// Creates an event hub in the Event Hubs namespace
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
 parent: eventHubsNamespace
 name: eventHubName
  //name: '${eventHubsNamespace.name}/${eventHubName}'
  properties: {
    messageRetentionInDays: retentionInDays
    partitionCount: partitionCount
  }
}

resource eventHubAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-11-01' = {
  name: 'listenpolicy'
  parent: eventHub
  properties: {
    rights: [
      'Listen'
    ]
  }
}
