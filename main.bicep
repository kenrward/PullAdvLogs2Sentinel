@secure()
param clientSecret string
@secure()
param workspaceKey string

param appName string
param location string = resourceGroup().location
param tenantId string
param clientId string
param WorkspaceId string



// storage accounts must be between 3 and 24 characters in length and use numbers and lower-case letters only
var storageAccountName = '${substring(appName,0,10)}${uniqueString(resourceGroup().id)}' 
var hostingPlanName = '${appName}${uniqueString(resourceGroup().id)}'
var appInsightsName = '${appName}${uniqueString(resourceGroup().id)}'
var keyVaultName = '${substring(appName,0,10)}${uniqueString(resourceGroup().id)}'
var functionAppName = appName

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppName}': 'Resource'
  }
}
resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
 name: hostingPlanName
 location: location
 sku: {
   name: 'Y1'
   tier: 'Dynamic'
 }
}
resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId 
    enabledForTemplateDeployment:true
    accessPolicies:[
      
    ]

  }
  resource kvsc 'secrets' = {
    name: 'clientSecret'
    properties: {
      value: clientSecret
    }
  }
  resource kvsw 'secrets' = {
    name: 'workspaceKey'
    properties: {
      value: workspaceKey
    }
  }
}


resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionAppName
  location: location
  identity: {
     type: 'SystemAssigned'
  }
  kind: 'functionapp'
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: true
    siteConfig: {
      appSettings: []
    }
  }
}

resource kvpolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-10-01' = {
  name: '${keyVaultName}/add'
  properties: {
     accessPolicies: [
      {
        objectId: resourceId('Microsoft.Web/sites',functionAppName)
        permissions:{
          secrets:[
            'get'
            'list'
        ]
        }
        tenantId: subscription().tenantId
      }
      ]
  }
}
resource function_appsettings 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'appsettings'
  parent: functionApp
  properties: {
    FUNCTIONS_EXTENSION_VERSION: '~3'
    FUNCTIONS_WORKER_RUNTIME: 'powershell'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
    WEBSITE_CONTENTSHARE: storageAccountName
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
    clientId: clientId
    clientSecret: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}_clientSecret.properties.secretUriWithVersion})'
    workspaceID: WorkspaceId
    workspaceKey: '@Microsoft.KeyVault(SecretUri=${keyVaultName}_workspaceKey.properties.secretUriWithVersion})'
    WEBSITE_RUN_FROM_PACKAGE: 'https://github.com/kenrward/PullAdvLogs2Sentinel/blob/master/PullAdvLogs2Sentinel.zip?raw=true'
    tenantId: tenantId
  }
}
