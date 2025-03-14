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
param summarizeVideoContentExists bool

@description('Definition of the app')
@secure()
param summarizeVideoContentDefinition object

@description('Resource ID of the managed identity')
param summarizeVideoContentIdentityResourceId string

@description('Client ID of the managed identity')
param summarizeVideoContentIdentityClientId string

@description('Secrets for the app')
param summarizeVideoContentSecrets array

@description('Environment variables for the app')
param summarizeVideoContentEnvVars array

// Deploy Summarize Video Content Container App
module summarizeVideoContent '../modules/container-app.bicep' = {
  name: 'summarizeVideoContentContainerApp'
  params: {
    name: 'summarizeVideoContent'
    location: location
    tags: tags
    applicationInsightsConnectionString: applicationInsightsConnectionString
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistryLoginServer
    exists: summarizeVideoContentExists
    appDefinition: summarizeVideoContentDefinition
    identityResourceId: summarizeVideoContentIdentityResourceId
    identityClientId: summarizeVideoContentIdentityClientId
    secrets: summarizeVideoContentSecrets
    envVars: summarizeVideoContentEnvVars
    imageName: 'summarize-video-content'
  }
}

output resourceId string = summarizeVideoContent.outputs.resourceId
