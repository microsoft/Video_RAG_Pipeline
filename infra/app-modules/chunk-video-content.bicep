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
param chunkVideoContentExists bool

@description('Definition of the app')
@secure()
param chunkVideoContentDefinition object

@description('Resource ID of the managed identity')
param chunkVideoContentIdentityResourceId string

@description('Client ID of the managed identity')
param chunkVideoContentIdentityClientId string

@description('Secrets for the app')
param chunkVideoContentSecrets array

@description('Environment variables for the app')
param chunkVideoContentEnvVars array

// Deploy Chunk Video Content Container App
module chunkVideoContent '../modules/container-app.bicep' = {
  name: 'chunkVideoContentContainerApp'
  params: {
    name: 'chunkVideoContent'
    location: location
    tags: tags
    applicationInsightsConnectionString: applicationInsightsConnectionString
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistryLoginServer
    exists: chunkVideoContentExists
    appDefinition: chunkVideoContentDefinition
    identityResourceId: chunkVideoContentIdentityResourceId
    identityClientId: chunkVideoContentIdentityClientId
    secrets: chunkVideoContentSecrets
    envVars: chunkVideoContentEnvVars
    imageName: 'chunk-video-content'
  }
}

output resourceId string = chunkVideoContent.outputs.resourceId
