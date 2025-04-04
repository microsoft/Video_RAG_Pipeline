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

@description('Resource token for unique resource naming')
param resourceToken string

@description('Abbreviations to use for resource naming')
param abbrs object

@description('Name of the app')
param name string = 'indexFileApi'

@description('Storage account name')
param storageAccountNameParam string

@description('Blob container name') 
param blobContainerNameParam string

@description('Container registry login server')
param containerRegistryLoginServer string

@description('Container registry name')
param containerRegistryName string

var keyVaultName = '${abbrs.keyVaultVaults}${resourceToken}-ifa' // shortened index-file-api because of a length limit

// Create managed identities for the container apps
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'indexFileApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}indexFileApi-${resourceToken}'
    location: location
  }
}

// Grant ACR Pull permissions to the identity on the shared container registry
module containerRegistryAccess '../roles/acr-pull-role.bicep' = {
  name: 'index-file-api-acr-access'
  params: {
    containerRegistryName: containerRegistryName
    principalId: identity.outputs.principalId
    appName: name
  }
}

// Deploy Index File API Container App
module indexFileApi '../container-app.bicep' = {
  name: 'indexFileApiContainerApp'
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
          keyVaultUrl: indexFileApiSecrets.outputs.serviceBusNamespaceSecretUri
        }
        {
          name: 'service-bus-api-key'
          keyVaultUrl: indexFileApiSecrets.outputs.serviceBusKeySecretUri
        }
        {
          name: 'index-file-queue'
          keyVaultUrl: indexFileApiSecrets.outputs.indexFileQueueNameSecretUri
        }
        {
          name: 'storage-account-name'
          keyVaultUrl: indexFileApiSecrets.outputs.storageAccountNameSecretUri
        }
        {
          name: 'storage-account-key'
          keyVaultUrl: indexFileApiSecrets.outputs.storageAccountKeySecretUri
        }
        {
          name: 'container-name'
          keyVaultUrl: indexFileApiSecrets.outputs.containerNameSecretUri
        }
      ]
    }
    envVars: [
      { name: 'SERVICE_BUS_NAMESPACE', secretRef: 'service-bus-namespace' }
      { name: 'SERVICE_BUS_API_KEY', secretRef: 'service-bus-api-key' }
      { name: 'INDEX_FILE_QUEUE', secretRef: 'index-file-queue' }
      { name: 'STORAGE_ACCOUNT_NAME', secretRef: 'storage-account-name' }
      { name: 'STORAGE_ACCOUNT_KEY', secretRef: 'storage-account-key' }
      { name: 'CONTAINER_NAME', secretRef: 'container-name' }
    ]
    imageName: 'index-file-api'
  }
  dependsOn: [
    keyVaultSecretUserRole    // Ensure Key Vault Secret User role exists
    indexFileQueue        // Ensure the index-file queue exists
    containerRegistryAccess   // Ensure ACR pull rights are granted
  ]
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
    indexFileApi
  ]
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

// Create secrets for index-file-api in a dedicated module
module indexFileApiSecrets 'secrets.bicep' = {
  name: 'indexFileApiSecrets'
  params: {
    keyVaultName: keyVaultName
    serviceBusNamespace: serviceBusNamespaceName
    storageAccountName: storageAccountNameParam
    blobContainerName: blobContainerNameParam
  }
  dependsOn: [
    keyVault
  ]
}

output resourceId string = indexFileApi.outputs.resourceId
output identityPrincipalId string = identity.outputs.principalId
output identityResourceId string = identity.outputs.resourceId
output identityClientId string = identity.outputs.clientId
