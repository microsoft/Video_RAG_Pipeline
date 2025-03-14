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

// Fetch latest images for each container app
module chunkVideoContentFetchLatestImage '../modules/fetch-container-image.bicep' = {
  name: 'chunkVideoContent-fetch-image'
  params: {
    exists: chunkVideoContentExists
    name: 'chunk-video-content'
  }
}

module indexFileApiFetchLatestImage '../modules/fetch-container-image.bicep' = {
  name: 'indexFileApi-fetch-image'
  params: {
    exists: indexFileApiExists
    name: 'index-file-api'
  }
}

module summarizeVideoContentFetchLatestImage '../modules/fetch-container-image.bicep' = {
  name: 'summarizeVideoContent-fetch-image'
  params: {
    exists: summarizeVideoContentExists
    name: 'summarize-video-content'
  }
}

// Process container app settings
var chunkVideoContentAppSettingsArray = filter(array(chunkVideoContentDefinition.settings), i => i.name != '')
var chunkVideoContentSecretSettings = map(filter(chunkVideoContentAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var chunkVideoContentEnvSettings = map(filter(chunkVideoContentAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

var indexFileApiAppSettingsArray = filter(array(indexFileApiDefinition.settings), i => i.name != '')
var indexFileApiSecretSettings = map(filter(indexFileApiAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var indexFileApiEnvSettings = map(filter(indexFileApiAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

var summarizeVideoContentAppSettingsArray = filter(array(summarizeVideoContentDefinition.settings), i => i.name != '')
var summarizeVideoContentSecretSettings = map(filter(summarizeVideoContentAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var summarizeVideoContentEnvSettings = map(filter(summarizeVideoContentAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

// Deploy the Chunk Video Content Container App
module chunkVideoContent 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'chunkVideoContent'
  params: {
    name: 'chunk-video-content'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList: chunkVideoContentSecrets
    }
    containers: [
      {
        image: chunkVideoContentFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: chunkVideoContentIdentityClientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        chunkVideoContentEnvVars,
        chunkVideoContentEnvSettings,
        map(chunkVideoContentSecretSettings, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [chunkVideoContentIdentityResourceId]
    }
    registries:[
      {
        server: containerRegistryLoginServer
        identity: chunkVideoContentIdentityResourceId
      }
    ]
    environmentResourceId: containerAppsEnvironmentResourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'chunk-video-content' })
  }
}

// Deploy the Index File API Container App
module indexFileApi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'indexFileApi'
  params: {
    name: 'index-file-api'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList: indexFileApiSecrets
    }
    containers: [
      {
        image: indexFileApiFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: indexFileApiIdentityClientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        indexFileApiEnvVars,
        indexFileApiEnvSettings,
        map(indexFileApiSecretSettings, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [indexFileApiIdentityResourceId]
    }
    registries:[
      {
        server: containerRegistryLoginServer
        identity: indexFileApiIdentityResourceId
      }
    ]
    environmentResourceId: containerAppsEnvironmentResourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'index-file-api' })
  }
}

// Deploy the Summarize Video Content Container App
module summarizeVideoContent 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'summarizeVideoContent'
  params: {
    name: 'summarize-video-content'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList: summarizeVideoContentSecrets
    }
    containers: [
      {
        image: summarizeVideoContentFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: summarizeVideoContentIdentityClientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        summarizeVideoContentEnvVars,
        summarizeVideoContentEnvSettings,
        map(summarizeVideoContentSecretSettings, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [summarizeVideoContentIdentityResourceId]
    }
    registries:[
      {
        server: containerRegistryLoginServer
        identity: summarizeVideoContentIdentityResourceId
      }
    ]
    environmentResourceId: containerAppsEnvironmentResourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'summarize-video-content' })
  }
}

output chunkVideoContentResourceId string = chunkVideoContent.outputs.resourceId
output indexFileApiResourceId string = indexFileApi.outputs.resourceId
output summarizeVideoContentResourceId string = summarizeVideoContent.outputs.resourceId