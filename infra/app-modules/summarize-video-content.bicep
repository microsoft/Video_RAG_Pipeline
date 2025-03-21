@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

@description('Whether the app exists')
param summarizeVideoContentExists bool

@description('Definition of the app')
@secure()
param summarizeVideoContentDefinition object

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

@description('Resource token for unique resource naming')
param resourceToken string

@description('Abbreviations to use for resource naming')
param abbrs object

@description('Name of the app')
param name string = 'summarizeVideoContent'

// Create managed identities for the container apps
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'summarizeVideoContentidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}summarizeVideoContent-${resourceToken}'
    location: location
  }
}

// Create container registry for this app with direct role assignment
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'summarize-video-content-registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}summ${resourceToken}'
    location: location
    tags: tags
    acrAdminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    roleAssignments: [
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
      }
    ]
  }
}

// Remove the separate ACR pull role assignment module

// Grant Storage Blob Data Contributor role to the identity
module storageBlobContributorRole '../modules/roles/storage-blob-contributor-role.bicep' = if (!empty(storageAccountName)) {
  name: '${name}-storage-blob-contributor-role'
  params: {
    storageAccountName: storageAccountName
    containerName: blobContainerName
    principalId: identity.outputs.principalId
    appName: name
  }
}

// Deploy Summarize Video Content Container App
module summarizeVideoContent '../modules/container-app.bicep' = {
  name: 'summarizeVideoContentContainerApp'
  params: {
    name: name
    location: location
    tags: tags
    applicationInsightsResourceId: applicationInsightsResourceId
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    exists: summarizeVideoContentExists
    appDefinition: summarizeVideoContentDefinition
    identityResourceId: identity.outputs.resourceId
    identityClientId: identity.outputs.clientId
    identityPrincipalId: identity.outputs.principalId
    secrets: summarizeVideoContentSecrets
    envVars: summarizeVideoContentEnvVars
    imageName: 'summarize-video-content'
  }
  dependsOn: [
    storageBlobContributorRole  // Ensure Storage Blob role exists
    finalizeContentQueue        // Ensure the finalize-content queue exists
    videoSummaryQueue           // Ensure the video-summary queue exists
    blobContainer               // Ensure the blob container exists
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

// Grant read access to the finalize content queue using the module
module finalizeReceiverRole '../modules/roles/service-bus-receiver-role.bicep' = if (summarizeVideoContentExists) {
  name: '${name}-finalize-receiver-role'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    queueName: 'finalize-content'
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn: [
    finalizeContentQueue
    summarizeVideoContent
  ]
}

// Grant write access to the video summary queue using the module
module videoSummarySenderRole '../modules/roles/service-bus-sender-role.bicep' = if (summarizeVideoContentExists) {
  name: '${name}-video-summary-sender-role'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    queueName: 'video-summary'
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn: [
    videoSummaryQueue
    summarizeVideoContent
  ]
}

// Remove existing Storage Blob Data Reader role assignment

output resourceId string = summarizeVideoContent.outputs.resourceId
output identityPrincipalId string = identity.outputs.principalId
output identityResourceId string = identity.outputs.resourceId
output identityClientId string = identity.outputs.clientId
output containerRegistryName string = containerRegistry.outputs.name
