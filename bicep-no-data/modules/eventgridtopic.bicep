@description('The name of the Event Grid custom topic.')
param eventGridTopicName string = 'topic-${uniqueString(resourceGroup().id)}'

@description('The location in which the Event Grid should be deployed.')
param location string = resourceGroup().location

resource eventGridTopic 'Microsoft.EventGrid/topics@2020-06-01' = {
  name: eventGridTopicName
  location: location
}

output eventGridTopicId string  = eventGridTopic.id
