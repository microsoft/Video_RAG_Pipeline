@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

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

@description('Resource token for unique resource naming')
param resourceToken string

@description('Abbreviations to use for resource naming')
param abbrs object

@description('Name of the app')
param name string = 'chunkVideoContent'

@description('Key Vault name')
param keyVaultName string

// Create managed identities for the container apps
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'chunkVideoContentidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}chunkVideoContent-${resourceToken}'
    location: location
  }
}

// Create container registry for this app with direct role assignment
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'chunk-video-content-registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}chunk${resourceToken}'
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

// Deploy Chunk Video Content Container App
module chunkVideoContent '../modules/container-app.bicep' = {
  name: 'chunkVideoContentContainerApp'
  params: {
    name: name
    location: location
    tags: tags
    applicationInsightsResourceId: applicationInsightsResourceId
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    identityResourceId: identity.outputs.resourceId
    identityClientId: identity.outputs.clientId
    secrets: chunkVideoContentSecrets
    envVars: chunkVideoContentEnvVars
    imageName: 'chunk-video-content'
  }
  dependsOn: [
    keyVaultSecretUserRole    // Ensure Key Vault Secret User role exists
    storageBlobContributorRole   // Ensure Storage Blob role exists
    finalizeContentQueue         // Ensure the finalize-content queue exists
    indexFileQueue               // Ensure the index-file queue exists
    blobContainer                // Ensure the blob container exists
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

// Grant write access to the finalize content queue using the module
module finalizeSenderRole '../modules/roles/service-bus-sender-role.bicep' = {
  name: '${name}-finalize-sender-role'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    queueName: 'finalize-content'
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn: [
    finalizeContentQueue
    chunkVideoContent
  ]
}

// Grant read access to the index file queue using the module
module indexReceiverRole '../modules/roles/service-bus-receiver-role.bicep' = {
  name: '${name}-index-receiver-role'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    queueName: 'index-file'
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn: [
    indexFileQueue
    chunkVideoContent
  ]
}


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

// Grant Key Vault Secret User role to the identity
module keyVaultSecretUserRole '../modules/roles/key-vault-secret-user-role.bicep' = {
  name: '${name}-key-vault-secret-user-role'
  params: {
    keyVaultName: keyVaultName
    principalId: identity.outputs.principalId
    appName: name
  }
}

output resourceId string = chunkVideoContent.outputs.resourceId
output identityPrincipalId string = identity.outputs.principalId
output identityResourceId string = identity.outputs.resourceId
output identityClientId string = identity.outputs.clientId
output containerRegistryName string = containerRegistry.outputs.name
