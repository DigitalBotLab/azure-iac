@description('Location of Azure Function')
param location string

@description('Virtual Network Name')
param virtualNetworkName string

@description('Storage Account name')
param storageAccountName string

@description('Name of the function app')
@maxLength(16)
param functionAppName string

@description('Name of the server farm')
param serverFarmName string

@description('Name of the LAW workspace')
param logAnalyticsName string

@description('Name of the subnet to connect the function to')
param functionsSubnetName string

@description('Digital Twins endpoint')
param digitalTwinsEndpoint string

@description('Name of application insights instance')
param applicationInsightsName string


@description('User Managed Identity Name to use')
param managedIdentityName string

@description('User Managed Identity Resource Group')
param managedIdentityGroup string


@description('Specifies the Azure Function hosting plan SKU.')
@allowed([
  'EP1'
  'EP2'
  'EP3'
])
param functionAppPlanSku string = 'EP1'

resource storageaccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

// create user assigned managed identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
  scope: resourceGroup(managedIdentityGroup)
}

resource serverfarm 'Microsoft.Web/serverfarms@2022-03-01' = {
  location: location
  name: serverFarmName
  kind: 'elastic'
  sku: {
    name: functionAppPlanSku
    tier: 'ElasticPremium'
    size: functionAppPlanSku
    family: 'EP'
  }
  properties: {
    maximumElasticWorkerCount: 4
    reserved: false
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource function 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    serverFarmId: serverfarm.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount.name};AccountKey=${storageaccount.listKeys().keys[0].value}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount.name};AccountKey=${storageaccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference('${appInsights.id}', '2020-02-02').InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'ADT_ENDPOINT'
          value: 'https://${digitalTwinsEndpoint}'
        }
      ]
    }
    vnetRouteAllEnabled: true
  }
}

resource planNetworkConfig 'Microsoft.Web/sites/networkConfig@2022-03-01' = {
  parent: function
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, functionsSubnetName)
    swiftSupported: true
  }
}
