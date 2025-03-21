@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

@description('Login server for the container registry')
param containerRegistryLoginServer string

@description('Whether the app exists')
param indexFileApiExists bool

@description('Definition of the app')
@secure()
param indexFileApiDefinition object

@description('Resource ID of the managed identity')
param indexFileApiIdentityResourceId string

@description('Client ID of the managed identity')
param indexFileApiIdentityClientId string

@description('Secrets for the app')
@secure()
param indexFileApiSecrets object

@description('Environment variables for the app')
param indexFileApiEnvVars array

@description('Service Bus namespace name')
param serviceBusNamespaceName string

// Deploy Index File API Container App
module indexFileApi '../modules/container-app.bicep' = {
  name: 'indexFileApiContainerApp'
  params: {
    name: 'indexFileApi'
    location: location
    tags: tags
    applicationInsightsResourceId: applicationInsightsResourceId
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistryLoginServer
    exists: indexFileApiExists
    appDefinition: indexFileApiDefinition
    identityResourceId: indexFileApiIdentityResourceId
    identityClientId: indexFileApiIdentityClientId
    secrets: indexFileApiSecrets
    envVars: indexFileApiEnvVars
    imageName: 'index-file-api'
  }
  dependsOn: [
    indexFileQueue  // Ensure the index-file queue exists
  ]
}

// Reference to the index-file queue
resource indexFileQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/index-file'
}

// Grant write access to the index file queue
resource writeAccessToIndexFileQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (indexFileApiExists) {
  name: guid(indexFileQueue.id, indexFileApiIdentityClientId, 'Sender')
  scope: indexFileQueue
  properties: {
    principalId: indexFileApiIdentityClientId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39') // Azure Service Bus Data Sender
    principalType: 'ServicePrincipal'
    description: 'Grant Index File API app write access to the index-file queue'
  }
  dependsOn: [
    indexFileQueue
    indexFileApi // Ensure the index-file queue exists
  ]
}

output resourceId string = indexFileApi.outputs.resourceId
