@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Connection string for Application Insights')
param applicationInsightsConnectionString string

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
param indexFileApiSecrets array

@description('Environment variables for the app')
param indexFileApiEnvVars array

// Deploy Index File API Container App
module indexFileApi '../modules/container-app.bicep' = {
  name: 'indexFileApiContainerApp'
  params: {
    name: 'indexFileApi'
    location: location
    tags: tags
    applicationInsightsConnectionString: applicationInsightsConnectionString
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
}

output resourceId string = indexFileApi.outputs.resourceId
