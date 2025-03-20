@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Principal IDs for managed identities that need access to the service bus')
param managedIdentityPrincipalIds array = []

@description('Resource token for unique resource naming')
param resourceToken string

@description('Name prefix abbreviations')
param abbrs object

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
    roleAssignments: [for principalId in managedIdentityPrincipalIds: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0') // Service Bus Data Sender
    }]
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
