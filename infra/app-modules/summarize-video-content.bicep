@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Connection string for Application Insights')
@secure()
param applicationInsightsConnectionString string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

@description('Login server for the container registry')
param containerRegistryLoginServer string

@description('Whether the app exists')
param summarizeVideoContentExists bool

@description('Definition of the app')
@secure()
param summarizeVideoContentDefinition object

@description('Resource ID of the managed identity')
param summarizeVideoContentIdentityResourceId string

@description('Client ID of the managed identity')
param summarizeVideoContentIdentityClientId string

@description('Secrets for the app')
@secure()
param summarizeVideoContentSecrets object

@description('Environment variables for the app')
param summarizeVideoContentEnvVars array

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Storage account name')
param storageAccountName string

@description('Blob container name')
param blobContainerName string

// Deploy Summarize Video Content Container App
module summarizeVideoContent '../modules/container-app.bicep' = {
  name: 'summarizeVideoContentContainerApp'
  params: {
    name: 'summarizeVideoContent'
    location: location
    tags: tags
    applicationInsightsConnectionString: applicationInsightsConnectionString
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistryLoginServer
    exists: summarizeVideoContentExists
    appDefinition: summarizeVideoContentDefinition
    identityResourceId: summarizeVideoContentIdentityResourceId
    identityClientId: summarizeVideoContentIdentityClientId
    secrets: summarizeVideoContentSecrets
    envVars: summarizeVideoContentEnvVars
    imageName: 'summarize-video-content'
  }
  dependsOn: [
    finalizeContentQueue   // Ensure the finalize-content queue exists
    videoSummaryQueue      // Ensure the video-summary queue exists
    blobContainer          // Ensure the blob container exists
  ]
}

// Reference to the finalize-content queue
resource finalizeContentQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/finalize-content'
}

// Reference to the video-summary queue (need to create this queue in service-bus.bicep)
resource videoSummaryQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/video-summary'
}

// Reference to the blob container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' existing = {
  name: '${storageAccountName}/default/${blobContainerName}'
}

// Grant read access to the finalize content queue
resource readAccessToFinalizeContentQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (summarizeVideoContentExists) {
  name: guid(finalizeContentQueue.id, summarizeVideoContentIdentityClientId, 'Receiver')
  scope: finalizeContentQueue
  properties: {
    principalId: summarizeVideoContentIdentityClientId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0') // Azure Service Bus Data Receiver
    principalType: 'ServicePrincipal'
    description: 'Grant Summarize Video Content app read access to the finalize-content queue'
  }
  dependsOn: [
    finalizeContentQueue
    summarizeVideoContent // Ensure the finalize-content queue exists
  ]
}

// Grant write access to the video summary queue
resource writeAccessToVideoSummaryQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (summarizeVideoContentExists) {
  name: guid(videoSummaryQueue.id, summarizeVideoContentIdentityClientId, 'Sender')
  scope: videoSummaryQueue
  properties: {
    principalId: summarizeVideoContentIdentityClientId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39') // Azure Service Bus Data Sender
    principalType: 'ServicePrincipal'
    description: 'Grant Summarize Video Content app write access to the video-summary queue'
  }
  dependsOn: [
    videoSummaryQueue
    summarizeVideoContent // Ensure the video-summary queue exists
  ]
}

// Grant Storage Blob Data Reader access to the blob container
resource blobContainerReaderAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (summarizeVideoContentExists) {
  name: guid(blobContainer.id, summarizeVideoContentIdentityClientId, 'BlobReader')
  scope: blobContainer
  properties: {
    principalId: summarizeVideoContentIdentityClientId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
    description: 'Grant Summarize Video Content app read access to the blob container'
  }
  dependsOn: [
    blobContainer
    summarizeVideoContent // Ensure the blob container exists
  ]
}

output resourceId string = summarizeVideoContent.outputs.resourceId
