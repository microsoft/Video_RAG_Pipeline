@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

@description('Login server for the container registry')
param containerRegistryLoginServer string

@description('Whether the app exists')
param chunkVideoContentExists bool

@description('Definition of the app')
@secure()
param chunkVideoContentDefinition object

@description('Resource ID of the managed identity')
param chunkVideoContentIdentityResourceId string

@description('Client ID of the managed identity')
param chunkVideoContentIdentityClientId string

@description('Secrets for the app')
@secure()
param chunkVideoContentSecrets object

@description('Environment variables for the app')
param chunkVideoContentEnvVars array

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Storage account name')
param storageAccountName string

@description('Blob container name')
param blobContainerName string

// Deploy Chunk Video Content Container App
module chunkVideoContent '../modules/container-app.bicep' = {
  name: 'chunkVideoContentContainerApp'
  params: {
    name: 'chunkVideoContent'
    location: location
    tags: tags
    applicationInsightsResourceId: applicationInsightsResourceId
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistryLoginServer
    exists: chunkVideoContentExists
    appDefinition: chunkVideoContentDefinition
    identityResourceId: chunkVideoContentIdentityResourceId
    identityClientId: chunkVideoContentIdentityClientId
    secrets: chunkVideoContentSecrets
    envVars: chunkVideoContentEnvVars
    imageName: 'chunk-video-content'
  }
  dependsOn: [
    finalizeContentQueue   // Ensure the finalize-content queue exists
    indexFileQueue         // Ensure the index-file queue exists
    blobContainer          // Ensure the blob container exists
  ]
}

// Reference to the finalize-content queue
resource finalizeContentQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/finalize-content'
}

// Reference to the index-file queue
resource indexFileQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/index-file'
}

// Reference to the blob container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' existing = {
  name: '${storageAccountName}/default/${blobContainerName}'
}

// Grant write access to the finalize content queue
resource writeAccessToFinalizeContentQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (chunkVideoContentExists) {
  name: guid(finalizeContentQueue.id, chunkVideoContentIdentityClientId, 'Sender')
  scope: finalizeContentQueue
  properties: {
    principalId: chunkVideoContentIdentityClientId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39') // Azure Service Bus Data Sender
    principalType: 'ServicePrincipal'
    description: 'Grant Chunk Video Content app write access to the finalize-content queue'
  }
  dependsOn: [
    finalizeContentQueue
    chunkVideoContent // Ensure the finalize-content queue exists
  ]
}

// Grant read access to the index file queue
resource readAccessToIndexFileQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (chunkVideoContentExists) {
  name: guid(indexFileQueue.id, chunkVideoContentIdentityClientId, 'Receiver')
  scope: indexFileQueue
  properties: {
    principalId: chunkVideoContentIdentityClientId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0') // Azure Service Bus Data Receiver
    principalType: 'ServicePrincipal'
    description: 'Grant Chunk Video Content app read access to the index-file queue'
  }
  dependsOn: [
    indexFileQueue
    chunkVideoContent // Ensure the index-file queue exists
  ]
}

// Grant Storage Blob Data Contributor access to the blob container
resource blobContainerContributorAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (chunkVideoContentExists) {
  name: guid(blobContainer.id, chunkVideoContentIdentityClientId, 'BlobContributor')
  scope: blobContainer
  properties: {
    principalId: chunkVideoContentIdentityClientId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
    description: 'Grant Chunk Video Content app read/write access to the blob container'
  }
  dependsOn: [
    blobContainer
    chunkVideoContent // Ensure the blob container exists
  ]
}

output resourceId string = chunkVideoContent.outputs.resourceId
