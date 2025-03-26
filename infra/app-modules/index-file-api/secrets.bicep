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

@description('The name of the OpenAI deployment')
param openAiDeploymentName string = ''

@description('API version for Service Bus operations')
param serviceBusApiVersion string = '2021-11-01'

@description('API version for Storage operations')
param storageApiVersion string = '2022-09-01'

// Storage Account secrets
resource storageAccountNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-api-storage-account-name'
  properties: {
    value: storageAccountName
  }
}

resource storageAccountApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-api-storage-account-key'
  properties: {
    value: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), storageApiVersion).keys[0].value
  }
}

resource containerNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-api-container-name'
  properties: {
    value: blobContainerName
  }
}

// Service Bus secrets
resource serviceBusNamespaceSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-api-service-bus-namespace'
  properties: {
    value: serviceBusNamespace
  }
}

resource serviceBusKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-api-service-bus-key'
  properties: {
    value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', serviceBusNamespace, 'RootManageSharedAccessKey'), serviceBusApiVersion).primaryKey
  }
}

resource indexFileQueueNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-api-queue-name'
  properties: {
    value: 'index-file'
  }
}

// Cognitive Services secrets (only added if cognitiveServicesAccountName is provided)
resource cognitiveServicesEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (!empty(cognitiveServicesAccountName)) {
  name: '${keyVaultName}/index-file-api-cognitive-services-endpoint'
  properties: {
    value: reference(resourceId('Microsoft.CognitiveServices/accounts', cognitiveServicesAccountName), '2023-05-01').endpoint
  }
}

resource cognitiveServicesKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (!empty(cognitiveServicesAccountName)) {
  name: '${keyVaultName}/index-file-api-cognitive-services-key'
  properties: {
    value: listKeys(resourceId('Microsoft.CognitiveServices/accounts', cognitiveServicesAccountName), '2023-05-01').key1
  }
}

resource openAiDeploymentNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (!empty(openAiDeploymentName)) {
  name: '${keyVaultName}/index-file-api-openai-deployment-name'
  properties: {
    value: openAiDeploymentName
  }
}

// Output secret URIs for reference by container apps
output storageAccountNameSecretUri string = storageAccountNameSecret.properties.secretUri
output storageAccountKeySecretUri string = storageAccountApiKeySecret.properties.secretUri
output containerNameSecretUri string = containerNameSecret.properties.secretUri
output serviceBusNamespaceSecretUri string = serviceBusNamespaceSecret.properties.secretUri
output serviceBusKeySecretUri string = serviceBusKeySecret.properties.secretUri
output indexFileQueueNameSecretUri string = indexFileQueueNameSecret.properties.secretUri
output cognitiveServicesEndpointSecretUri string = !empty(cognitiveServicesAccountName) ? cognitiveServicesEndpointSecret.properties.secretUri : ''
output cognitiveServicesKeySecretUri string = !empty(cognitiveServicesAccountName) ? cognitiveServicesKeySecret.properties.secretUri : ''
output openAiDeploymentNameSecretUri string = !empty(openAiDeploymentName) ? openAiDeploymentNameSecret.properties.secretUri : ''
