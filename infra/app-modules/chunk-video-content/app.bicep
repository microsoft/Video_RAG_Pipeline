@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Storage account name')
param storageAccountName string

@description('Blob container name')
param blobContainerName string

@description('Cognitive Services account name')
param cognitiveServicesAccountName string = ''

@description('Resource token for unique resource naming')
param resourceToken string

@description('Container Registry Login Server')
param containerRegistryLoginServer string

@description('Container Registry Name')
param containerRegistryName string

@description('Abbreviations to use for resource naming')
param abbrs object

@description('Name of the app')
param name string = 'chunkVideoContent'

var keyVaultName = '${abbrs.keyVaultVaults}${resourceToken}-cvc' // shortened chunk-video-content because of a length limit

// Create managed identities for the container apps
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'chunkVideoContentIdentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}chunkVideoContent-${resourceToken}'
    location: location
  }
}

// Deploy Key Vault without inline secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: keyVaultName
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enableRbacAuthorization: true
  }
}

// Create secrets for chunk-video-content in a dedicated module
module chunkVideoContentSecrets 'secrets.bicep' = {
  name: 'chunkVideoContentSecrets'
  params: {
    keyVaultName: keyVaultName
    serviceBusNamespace: serviceBusNamespaceName
    storageAccountName: storageAccountName
    blobContainerName: blobContainerName
    cognitiveServicesAccountName: cognitiveServicesAccountName
  }
  dependsOn: [
    keyVault
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

// Grant Key Vault Secret User role to the identity
module keyVaultSecretUserRole '../roles/key-vault-secret-user-role.bicep' = {
  name: '${name}-key-vault-secret-user-role'
  params: {
    keyVaultName: keyVaultName
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn:[
    keyVault
  ]
}

// Grant write access to the finalize content queue using the module
module finalizeSenderRole '../roles/service-bus-sender-role.bicep' = {
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

// Grant write access to the index file queue using the module
module indexSenderRole '../roles/service-bus-sender-role.bicep' = {
  name: '${name}-index-sender-role'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    queueName: 'index-file'
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn: [
    indexFileQueue
  ]
}

// Grant AcrPull role to the identity on the container registry
module acrPullRole '../roles/acr-pull-role.bicep' = {
  name: '${name}-acr-pull-role'
  params: {
    containerRegistryName: containerRegistryName
    principalId: identity.outputs.principalId
    appName: name
  }
}

// Deploy Chunk Video Content Container App
module chunkVideoContent '../container-app.bicep' = {
  name: 'chunkVideoContentContainerApp'
  params: {
    name: name
    location: location
    tags: tags
    applicationInsightsResourceId: applicationInsightsResourceId
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistryLoginServer
    identityResourceId: identity.outputs.resourceId
    identityClientId: identity.outputs.clientId
    secrets: {
      secrets: [
        {
          name: 'service-bus-namespace'
          keyVaultUrl: chunkVideoContentSecrets.outputs.serviceBusNamespaceSecretUri
        }
        {
          name: 'service-bus-key'
          keyVaultUrl: chunkVideoContentSecrets.outputs.serviceBusKeySecretUri
        }
        {
          name: 'index-file-queue'
          keyVaultUrl: chunkVideoContentSecrets.outputs.indexFileQueueNameSecretUri
        }
        {
          name: 'storage-account-name'
          keyVaultUrl: chunkVideoContentSecrets.outputs.storageAccountNameSecretUri
        }
        {
          name: 'storage-account-key'
          keyVaultUrl: chunkVideoContentSecrets.outputs.storageAccountKeySecretUri
        }
        {
          name: 'container-name'
          keyVaultUrl: chunkVideoContentSecrets.outputs.containerNameSecretUri
        }
        {
          name: 'content-understanding-endpoint'
          keyVaultUrl: chunkVideoContentSecrets.outputs.contentUnderstandingEndpointSecretUri
        }
        {
          name: 'content-understanding-key'
          keyVaultUrl: chunkVideoContentSecrets.outputs.contentUnderstandingKeySecretUri
        }
        {
          name: 'content-understanding-api-version'
          keyVaultUrl: chunkVideoContentSecrets.outputs.contentUnderstandingApiVersionSecretUri
        }
      ]
    }
    envVars: [
      { name: 'SERVICE_BUS_NAMESPACE', secretRef: 'service-bus-namespace' }
      { name: 'SERVICE_BUS_KEY', secretRef: 'service-bus-key' }
      { name: 'INDEX_FILE_QUEUE', secretRef: 'index-file-queue' }
      { name: 'STORAGE_ACCOUNT_NAME', secretRef: 'storage-account-name' }
      { name: 'STORAGE_ACCOUNT_KEY', secretRef: 'storage-account-key' }
      { name: 'CONTAINER_NAME', secretRef: 'container-name' }
      { name: 'CONTENT_UNDERSTANDING_ENDPOINT', secretRef: 'content-understanding-endpoint' }
      { name: 'CONTENT_UNDERSTANDING_KEY', secretRef: 'content-understanding-key' }
      { name: 'CONTENT_UNDERSTANDING_API_VERSION', secretRef: 'content-understanding-api-version' }
    ]
    imageName: 'chunk-video-content'
  }
  dependsOn: [
    keyVaultSecretUserRole
    indexSenderRole
  ]
}

output resourceId string = chunkVideoContent.outputs.resourceId
output identityPrincipalId string = identity.outputs.principalId
output identityResourceId string = identity.outputs.resourceId
output identityClientId string = identity.outputs.clientId
