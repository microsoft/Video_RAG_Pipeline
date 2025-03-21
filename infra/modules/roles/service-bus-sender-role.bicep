@description('Service Bus Namespace name')
param serviceBusNamespaceName string

@description('Queue name')
param queueName string

@description('Principal ID of the identity that needs Service Bus Data Sender access')
param principalId string

@description('Name of the app for description purposes')
param appName string

// Reference the service bus queue
resource queue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/${queueName}'
}

// Assign the Service Bus Data Sender role to the identity
resource senderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(queue.id, principalId, 'Sender')
  scope: queue
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39') // Azure Service Bus Data Sender
    principalType: 'ServicePrincipal'
    description: 'Grant ${appName} app write access to the ${queueName} queue'
  }
}

// Output the role assignment ID for reference
output roleAssignmentId string = senderRoleAssignment.id
