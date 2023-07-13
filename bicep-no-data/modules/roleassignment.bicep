@description('Existing Digital Twin resource name')
param digitalTwinsName string

@description('The principal id associated with identity on the Digital Twins resource')
param digitalTwinsIdentityPrincipalId string

@description('Existing Event Hubs namespace resource name')
param eventHubsNamespaceName string

@description('Existing event hub name')
param eventHubName string

@description('The id that will be given data owner permission for the Digital Twins resource')
param principalId string

@description('The type of the given principal id')
param principalType string

// Azure RBAC Guid Source: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var azureRbacAzureEventHubsDataOwner = 'f526a384-b230-433a-b45c-95f59c4a2dec'
var azureRbacAzureDigitalTwinsDataOwner = 'bcd981a7-7f74-457b-83e1-cceb9e632ffe'

// Gets Digital Twins resource
resource digitalTwins 'Microsoft.DigitalTwins/digitalTwinsInstances@2022-10-31' existing = {
  name: digitalTwinsName
}

// Gets event hub in Event Hubs namespace
resource eventhub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' existing = {
  name: '${eventHubsNamespaceName}/${eventHubName}'
}

// Assigns the given principal id input data owner of Digital Twins resource
resource givenIdToDigitalTwinsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(digitalTwins.id, principalId, azureRbacAzureDigitalTwinsDataOwner)
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureRbacAzureDigitalTwinsDataOwner)
    principalType: principalType
  }
}

// Assigns the given principal id input data owner of Digital Twins resource
resource ManagedIdToDigitalTwinsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(digitalTwins.id, digitalTwinsIdentityPrincipalId, azureRbacAzureDigitalTwinsDataOwner)
  properties: {
    principalId: digitalTwinsIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureRbacAzureDigitalTwinsDataOwner)
    principalType:'ServicePrincipal'
  }
}

// Assigns Digital Twins resource data owner of event hub
resource digitalTwinsToEventHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eventhub.id, principalId, azureRbacAzureEventHubsDataOwner)
  properties: {
    principalId: digitalTwinsIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureRbacAzureEventHubsDataOwner)
    principalType: 'ServicePrincipal'
  }
}
