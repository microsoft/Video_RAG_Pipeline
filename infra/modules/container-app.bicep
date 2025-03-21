@description('The name of the container app')
param name string

@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Container Apps Environment Resource ID')
param containerAppsEnvironmentResourceId string

@description('Container Registry Login Server')
param containerRegistryLoginServer string

@description('Whether the app exists (for fetching latest image)')
param exists bool

@description('App definition with settings')
@secure()
param appDefinition object

@description('Identity resource ID')
param identityResourceId string

@description('Identity client ID')
param identityClientId string

@description('App secrets')
@secure()
param secrets object

@description('Environment variables')
param envVars array

@description('Name to fetch the latest image')
param imageName string

// Get the Application Insights resource using its ID
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: split(applicationInsightsResourceId, '/')[8] // Extract name from resource ID
  scope: resourceGroup(split(applicationInsightsResourceId, '/')[2], split(applicationInsightsResourceId, '/')[4]) // Extract subscription and resource group
}

// Process app settings
var settingsArray = filter(array(appDefinition.settings), i => i.name != '')
var secretSettings = map(filter(settingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var envSettings = map(filter(settingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

// Fetch latest image
module fetchLatestImage '../modules/fetch-container-image.bicep' = {
  name: '${name}-fetch-image'
  params: {
    exists: exists
    name: imageName
  }
}

// Deploy container app
module app 'br/public:avm/res/app/container-app:0.8.0' = {
  name: name
  params: {
    name: imageName
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList: secrets.secrets
    }
    containers: [
      {
        image: fetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: appInsights.properties.ConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: identityClientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        envVars,
        envSettings,
        map(secretSettings, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [identityResourceId]
    }
    registries: [
      {
        server: containerRegistryLoginServer
        identity: identityResourceId
      }
    ]
    environmentResourceId: containerAppsEnvironmentResourceId
    location: location
    tags: union(tags, { 'azd-service-name': imageName })
  }
}

output resourceId string = app.outputs.resourceId
