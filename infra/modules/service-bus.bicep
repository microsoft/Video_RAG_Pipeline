@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Resource token for unique resource naming')
param resourceToken string

@description('Name prefix abbreviations')
param abbrs object

@description('The name of the key vault to store secrets')
param keyVaultName string

// Deploy Service Bus Namespace
module serviceBus 'br/public:avm/res/service-bus/namespace:0.4.0' = {
  name: 'service-bus'
  params: {
    name: '${abbrs.serviceBusNamespaces}${resourceToken}'
    location: location
    tags: tags
    skuObject: {
      name: 'Standard'
      capacity: 1
    }
  }
}

resource serviceBusKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/service-bus-key'
  properties: {
    value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', '${abbrs.serviceBusNamespaces}${resourceToken}', 'RootManageSharedAccessKey'), '2021-11-01').primaryKey
  }
  dependsOn: [
    serviceBus // Ensure Service Bus exists first
  ]
}

resource serviceBusKeyName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/service-bus-api-key-name'
  properties: {
    value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', '${abbrs.serviceBusNamespaces}${resourceToken}', 'RootManageSharedAccessKey'), '2021-11-01').keyName
  }
  dependsOn: [
    serviceBus // Ensure Service Bus exists first
  ]
}

// Store the Service Bus namespace name in Key Vault
resource serviceBusNamespace 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/service-bus-namespace'
  properties: {
    value: '${abbrs.serviceBusNamespaces}${resourceToken}'
  }
  dependsOn: [
    serviceBus // Ensure Service Bus exists first
  ]
}

resource indexFileQueueName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/index-file-queue-name'
  properties: {
    value: indexFileQueue.name
  }
}

resource finalizeContentQueueName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/finalize-content-queue-name'
  properties: {
    value: finalizeContentQueue.name
  }
}

resource videoSummaryQueueName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVaultName}/video-summary-queue-name'
  properties: {
    value: videoSummaryQueue.name
  }
}

// Create a queue for indexing files
resource indexFileQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = {
  name: '${abbrs.serviceBusNamespaces}${resourceToken}/index-file'
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    enablePartitioning: false
    enableExpress: false
  }
  dependsOn: [
    serviceBus // Ensure the Service Bus namespace exists
  ]
}

// Create a queue for finalizing content
resource finalizeContentQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = {
  name: '${abbrs.serviceBusNamespaces}${resourceToken}/finalize-content'
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    enablePartitioning: false
    enableExpress: false
  }
  dependsOn: [
    serviceBus // Ensure the Service Bus namespace exists
  ]
}

// Create a queue for video summary
resource videoSummaryQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = {
  name: '${abbrs.serviceBusNamespaces}${resourceToken}/video-summary'
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    enablePartitioning: false
    enableExpress: false
  }
  dependsOn: [
    serviceBus // Ensure the Service Bus namespace exists
  ]
}

output serviceBusNamespaceName string = serviceBus.outputs.name
output serviceBusEndpoint string = '${serviceBus.outputs.name}.servicebus.windows.net'
output indexFileQueueName string = 'index-file'
output finalizeContentQueueName string = 'finalize-content'
output videoSummaryQueueName string = 'video-summary'
