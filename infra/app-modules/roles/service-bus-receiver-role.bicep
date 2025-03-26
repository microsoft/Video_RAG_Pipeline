@description('Service Bus Namespace name')
param serviceBusNamespaceName string

@description('Queue name')
param queueName string

@description('Principal ID of the identity that needs Service Bus Data Receiver access')
param principalId string

@description('Name of the app for description purposes')
param appName string

// Reference the service bus queue
resource queue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/${queueName}'
}

// Assign the Service Bus Data Receiver role to the identity
resource receiverRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(queue.id, principalId, 'Receiver')
  scope: queue
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0') // Azure Service Bus Data Receiver
    principalType: 'ServicePrincipal'
    description: 'Grant ${appName} app read access to the ${queueName} queue'
  }
}

// Output the role assignment ID for reference
output roleAssignmentId string = receiverRoleAssignment.id
