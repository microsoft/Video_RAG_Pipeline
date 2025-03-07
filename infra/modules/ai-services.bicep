@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Name of the Foundry Hub')
param foundryHubName string = 'foundryHub'

@description('Resource ID of the container registry')
param containerRegistryResourceId string

@description('Resource ID of the Application Insights instance')
param applicationInsightsResourceId string

@description('Resource ID of the Key Vault')
param keyVaultResourceId string

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2023-08-01-preview' = {
  name: foundryHubName
  location: location
  kind: 'hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Azure AI Foundry Hub'
    friendlyName: 'AI Foundry Hub'
    publicNetworkAccess: 'Enabled'
    containerRegistry: containerRegistryResourceId
    applicationInsights: applicationInsightsResourceId
    keyVault: keyVaultResourceId
  }
  tags: tags
}

output resourceId string = aiHub.id
output name string = aiHub.name
output principalId string = aiHub.identity.principalId
