@description('The name of the Key Vault to store secrets')
param keyVaultName string

@description('The name of the Service Bus namespace')
param serviceBusNamespace string

@description('The name of the blob container')
param blobContainerName string

@description('The name of the Storage Account')
param storageAccountName string

// Store Storage Account API Key in Key Vault
resource storageAccountApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/storage-account-api-key'
  properties: {
    value: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2022-09-01').keys[0].value
  }
}

// Secrets are in a dedicated module so we can make the module dependent on other
// resources. The listKeys function does not respect dependsOn applied directly
// to the resource
// https://github.com/Azure/bicep/issues/7402

// Service Bus primary key secret
resource serviceBusKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/service-bus-key'
  properties: {
    value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', serviceBusNamespace, 'RootManageSharedAccessKey'), '2021-11-01').primaryKey
  }
}

// Service Bus key name secret
resource serviceBusKeyNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/service-bus-api-key-name'
  properties: {
    value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', serviceBusNamespace, 'RootManageSharedAccessKey'), '2021-11-01').keyName
  }
}

// Store the Service Bus namespace name in Key Vault
resource serviceBusNamespaceSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/service-bus-namespace'
  properties: {
    value: serviceBusNamespace
  }
}

resource indexFileQueueNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-queue-name'
  properties: {
    value: 'index-file'
  }
}

resource finalizeContentQueueNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/finalize-content-queue-name'
  properties: {
    value: 'finalize-content'
  }
}

resource videoSummaryQueueNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/video-summary-queue-name'
  properties: {
    value: 'video-summary'
  }
}


// Store simple secrets in Key Vault
resource storageAccountNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/storage-account-name'
  properties: {
    value: storageAccountName
  }
}

// Store Container Name in Key Vault
resource containerNameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/container-name'
  properties: {
    value: blobContainerName
  }
}
