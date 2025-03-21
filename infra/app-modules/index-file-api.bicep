@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

@description('Whether the app exists')
param indexFileApiExists bool

@description('Definition of the app')
@secure()
param indexFileApiDefinition object

@description('Secrets for the app')
@secure()
param indexFileApiSecrets object

@description('Environment variables for the app')
param indexFileApiEnvVars array

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Resource token for unique resource naming')
param resourceToken string

@description('Abbreviations to use for resource naming')
param abbrs object

@description('Name of the app')
param name string = 'indexFileApi'

// Create managed identities for the container apps
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'indexFileApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}indexFileApi-${resourceToken}'
    location: location
  }
}

// Create container registry for this app with direct role assignment
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'index-file-api-registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}index${resourceToken}'
    location: location
    tags: tags
    acrAdminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    roleAssignments: [
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
      }
    ]
  }
}

// Deploy Index File API Container App
module indexFileApi '../modules/container-app.bicep' = {
  name: 'indexFileApiContainerApp'
  params: {
    name: name
    location: location
    tags: tags
    applicationInsightsResourceId: applicationInsightsResourceId
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    exists: indexFileApiExists
    appDefinition: indexFileApiDefinition
    identityResourceId: identity.outputs.resourceId
    identityClientId: identity.outputs.clientId
    identityPrincipalId: identity.outputs.principalId
    secrets: indexFileApiSecrets
    envVars: indexFileApiEnvVars
    imageName: 'index-file-api'
  }
  dependsOn: [
    indexFileQueue        // Ensure the index-file queue exists
  ]
}

// Reference to the index-file queue
resource indexFileQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/index-file'
}

// Grant write access to the index file queue using the module
module indexSenderRole '../modules/roles/service-bus-sender-role.bicep' = if (indexFileApiExists) {
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

output resourceId string = indexFileApi.outputs.resourceId
output identityPrincipalId string = identity.outputs.principalId
output identityResourceId string = identity.outputs.resourceId
output identityClientId string = identity.outputs.clientId
output containerRegistryName string = containerRegistry.outputs.name
