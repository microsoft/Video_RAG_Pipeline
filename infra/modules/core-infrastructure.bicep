@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Name of the blob container to create in the storage account')
param blobContainerName string = 'videos'

@description('Name of the Key Vault')
param keyVaultName string

var abbrs = loadJsonContent('../abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

var storageAccountName = '${abbrs.storageStorageAccounts}${resourceToken}'

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

// Deploy Key Vault
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: 'keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enableRbacAuthorization: true
    secrets: [
      {
        name: 'storage-account-name'
        value: storageAccount.outputs.name
      }
      {
        name: 'storage-account-api-key'
        value: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2022-09-01').keys[0].value
      }
      {
        name: 'container-name'
        value: blobContainerName
      }
    ]
  }
}

// Deploy Storage Account
module storageAccount 'br/public:avm/res/storage/storage-account:0.6.0' = {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    publicNetworkAccess: 'Enabled'
    allowBlobPublicAccess: false
    defaultToOAuthAuthentication: true
  }
}

// Create Blob Container in Storage Account
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${abbrs.storageStorageAccounts}${resourceToken}/default/${blobContainerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccount // Ensure the Storage Account exists
  ]
}

output logAnalyticsWorkspaceResourceId string = monitoring.outputs.logAnalyticsWorkspaceResourceId
output applicationInsightsResourceId string = monitoring.outputs.applicationInsightsResourceId
output containerAppsEnvironmentResourceId string = containerAppsEnvironment.outputs.resourceId
output keyVaultResourceId string = keyVault.outputs.resourceId
output keyVaultUri string = keyVault.outputs.uri
output keyVaultName string = keyVault.outputs.name
output storageAccountResourceId string = storageAccount.outputs.resourceId
output storageAccountName string = storageAccount.outputs.name
output blobContainerName string = blobContainerName
output blobEndpoint string = storageAccount.outputs.primaryBlobEndpoint
