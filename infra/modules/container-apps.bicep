@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('ApplicationInsights Connection String')
param applicationInsightsConnectionString string

@description('Container Apps Environment Resource ID')
param containerAppsEnvironmentResourceId string

@description('Container Registry Login Server')
param containerRegistryLoginServer string

// Chunk Video Content App parameters
param chunkVideoContentExists bool
@secure()
param chunkVideoContentDefinition object
param chunkVideoContentIdentityResourceId string
param chunkVideoContentIdentityClientId string
param chunkVideoContentSecrets array
param chunkVideoContentEnvVars array

// Index File API parameters
param indexFileApiExists bool
@secure()
param indexFileApiDefinition object
param indexFileApiIdentityResourceId string
param indexFileApiIdentityClientId string
param indexFileApiSecrets array
param indexFileApiEnvVars array

// Summarize Video Content parameters
param summarizeVideoContentExists bool
@secure()
param summarizeVideoContentDefinition object
param summarizeVideoContentIdentityResourceId string
param summarizeVideoContentIdentityClientId string
param summarizeVideoContentSecrets array
param summarizeVideoContentEnvVars array

// Deploy Chunk Video Content Container App
module chunkVideoContent './container-app.bicep' = {
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

// Deploy Index File API Container App
module indexFileApi './container-app.bicep' = {
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

// Deploy Summarize Video Content Container App
module summarizeVideoContent './container-app.bicep' = {
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

// Output the resource IDs
output chunkVideoContentResourceId string = chunkVideoContent.outputs.resourceId
output indexFileApiResourceId string = indexFileApi.outputs.resourceId
output summarizeVideoContentResourceId string = summarizeVideoContent.outputs.resourceId
