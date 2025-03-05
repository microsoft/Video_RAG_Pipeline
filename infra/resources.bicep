@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}


param chunkVideoContentExists bool
@secure()
param chunkVideoContentDefinition object
param indexFileApiExists bool
@secure()
param indexFileApiDefinition object
param summarizeVideoContentExists bool
@secure()
param summarizeVideoContentDefinition object

@description('Id of the user or app to assign application roles')
param principalId string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    acrAdminUserEnabled: true
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments:[
      {
        principalId: chunkVideoContentIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: indexFileApiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: summarizeVideoContentIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

module chunkVideoContentIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'chunkVideoContentidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}chunkVideoContent-${resourceToken}'
    location: location
  }
}

module chunkVideoContentFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'chunkVideoContent-fetch-image'
  params: {
    exists: chunkVideoContentExists
    name: 'chunk-video-content'
  }
}

var chunkVideoContentAppSettingsArray = filter(array(chunkVideoContentDefinition.settings), i => i.name != '')
var chunkVideoContentSecrets = map(filter(chunkVideoContentAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var chunkVideoContentEnv = map(filter(chunkVideoContentAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module chunkVideoContent 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'chunkVideoContent'
  params: {
    name: 'chunk-video-content'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(chunkVideoContentSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
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
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: chunkVideoContentIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        chunkVideoContentEnv,
        map(chunkVideoContentSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [chunkVideoContentIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: chunkVideoContentIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'chunk-video-content' })
  }
}

module indexFileApiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'indexFileApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}indexFileApi-${resourceToken}'
    location: location
  }
}

module indexFileApiFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'indexFileApi-fetch-image'
  params: {
    exists: indexFileApiExists
    name: 'index-file-api'
  }
}

var indexFileApiAppSettingsArray = filter(array(indexFileApiDefinition.settings), i => i.name != '')
var indexFileApiSecrets = map(filter(indexFileApiAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var indexFileApiEnv = map(filter(indexFileApiAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module indexFileApi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'indexFileApi'
  params: {
    name: 'index-file-api'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(indexFileApiSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
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
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: indexFileApiIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        indexFileApiEnv,
        map(indexFileApiSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [indexFileApiIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: indexFileApiIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'index-file-api' })
  }
}

module summarizeVideoContentIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'summarizeVideoContentidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}summarizeVideoContent-${resourceToken}'
    location: location
  }
}

module summarizeVideoContentFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'summarizeVideoContent-fetch-image'
  params: {
    exists: summarizeVideoContentExists
    name: 'summarize-video-content'
  }
}

var summarizeVideoContentAppSettingsArray = filter(array(summarizeVideoContentDefinition.settings), i => i.name != '')
var summarizeVideoContentSecrets = map(filter(summarizeVideoContentAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var summarizeVideoContentEnv = map(filter(summarizeVideoContentAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module summarizeVideoContent 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'summarizeVideoContent'
  params: {
    name: 'summarize-video-content'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(summarizeVideoContentSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
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
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: summarizeVideoContentIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        summarizeVideoContentEnv,
        map(summarizeVideoContentSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [summarizeVideoContentIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: summarizeVideoContentIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'summarize-video-content' })
  }
}
// Create a keyvault to store secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: 'keyvault'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    enableRbacAuthorization: false
    accessPolicies: [
      {
        objectId: principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: chunkVideoContentIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: indexFileApiIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: summarizeVideoContentIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
    ]
    secrets: [
    ]
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_RESOURCE_CHUNK_VIDEO_CONTENT_ID string = chunkVideoContent.outputs.resourceId
output AZURE_RESOURCE_INDEX_FILE_API_ID string = indexFileApi.outputs.resourceId
output AZURE_RESOURCE_SUMMARIZE_VIDEO_CONTENT_ID string = summarizeVideoContent.outputs.resourceId
