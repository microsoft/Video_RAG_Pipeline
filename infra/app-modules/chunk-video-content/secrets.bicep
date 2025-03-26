@description('The name of the Key Vault to store secrets')
param keyVaultName string

@description('The name of the Service Bus namespace')
param serviceBusNamespace string

@description('The name of the Storage Account')
param storageAccountName string

@description('The name of the blob container')
param blobContainerName string

@description('The name of the Cognitive Services account')
param cognitiveServicesAccountName string = ''

@description('API version for Service Bus operations')
param serviceBusApiVersion string = '2021-11-01'

@description('API version for Storage operations')
param storageApiVersion string = '2022-09-01'

@description('API version for Cognitive Services operations')
param cognitiveServicesApiVersion string = '2023-05-01'

// Storage Account secrets
resource storageAccountNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/chunk-video-storage-account-name'
  properties: {
    value: storageAccountName
  }
}

resource storageAccountApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/chunk-video-storage-account-key'
  properties: {
    value: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), storageApiVersion).keys[0].value
  }
}

resource containerNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/chunk-video-container-name'
  properties: {
    value: blobContainerName
  }
}

// Service Bus secrets
resource serviceBusNamespaceSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/chunk-video-service-bus-namespace'
  properties: {
    value: serviceBusNamespace
  }
}

resource serviceBusKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/chunk-video-service-bus-key'
  properties: {
    value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', serviceBusNamespace, 'RootManageSharedAccessKey'), serviceBusApiVersion).primaryKey
  }
}

// Queue names
resource indexFileQueueNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/chunk-video-index-file-queue'
  properties: {
    value: 'index-file'
  }
}

// Cognitive Services secrets
resource contentUnderstandingEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (!empty(cognitiveServicesAccountName)) {
  name: '${keyVaultName}/chunk-video-content-understanding-endpoint'
  properties: {
    value: reference(resourceId('Microsoft.CognitiveServices/accounts', cognitiveServicesAccountName), cognitiveServicesApiVersion).endpoint
  }
}

resource contentUnderstandingKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (!empty(cognitiveServicesAccountName)) {
  name: '${keyVaultName}/chunk-video-content-understanding-key'
  properties: {
    value: listKeys(resourceId('Microsoft.CognitiveServices/accounts', cognitiveServicesAccountName), cognitiveServicesApiVersion).key1
  }
}

resource contentUnderstandingApiVersionSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/chunk-video-content-understanding-api-version'
  properties: {
    value: '2024-12-01-preview'
  }
}

// Output secret URIs for reference by container apps
output storageAccountNameSecretUri string = storageAccountNameSecret.properties.secretUri
output storageAccountKeySecretUri string = storageAccountApiKeySecret.properties.secretUri
output containerNameSecretUri string = containerNameSecret.properties.secretUri
output serviceBusNamespaceSecretUri string = serviceBusNamespaceSecret.properties.secretUri
output serviceBusKeySecretUri string = serviceBusKeySecret.properties.secretUri
output indexFileQueueNameSecretUri string = indexFileQueueNameSecret.properties.secretUri
output contentUnderstandingEndpointSecretUri string = !empty(cognitiveServicesAccountName) ? contentUnderstandingEndpointSecret.properties.secretUri : ''
output contentUnderstandingKeySecretUri string = !empty(cognitiveServicesAccountName) ? contentUnderstandingKeySecret.properties.secretUri : ''
output contentUnderstandingApiVersionSecretUri string = contentUnderstandingApiVersionSecret.properties.secretUri
