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

// Parameters added for service bus secrets
@description('Service Bus Namespace')
param serviceBusNamespace string = ''
@secure()
@description('Service Bus API Key')
param serviceBusApiKey string = ''
@description('Service Bus API Key Name')
param serviceBusApiKeyName string = ''

// Parameters added for content understanding secrets
@description('Content Understanding Endpoint')
param contentUnderstandingEndpoint string = ''
@secure()
@description('Content Understanding Key')
param contentUnderstandingKey string = ''
@description('Content Understanding API Version')
param contentUnderstandingApiVersion string = ''

// Parameters added for Azure OpenAI secrets
@description('Azure OpenAI Endpoint')
param azureOpenAIEndpoint string = ''
@secure()
@description('Azure OpenAI Key')
param azureOpenAIKey string = ''
@description('Azure OpenAI API Version')
param azureOpenAIApiVersion string = ''
@description('Azure OpenAI Model Name')
param azureOpenAIModelName string = ''

// Parameter added for Storage Account API Key
@secure()
@description('Storage Account API Key')
param storageAccountApiKey string = ''

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
      secureList: [
        {
          name: 'service-bus-namespace'
          value: !empty(serviceBusNamespace) ? serviceBusNamespace : 'placeholder-value'
        }
        {
          name: 'service-bus-api-key'
          value: !empty(serviceBusApiKey) ? serviceBusApiKey : 'placeholder-value'
        }
        {
          name: 'service-bus-api-key-name'
          value: !empty(serviceBusApiKeyName) ? serviceBusApiKeyName : 'placeholder-value'
        }
        {
          name: 'content-understanding-endpoint'
          value: !empty(contentUnderstandingEndpoint) ? contentUnderstandingEndpoint : 'placeholder-value'
        }
        {
          name: 'content-understanding-key'
          value: !empty(contentUnderstandingKey) ? contentUnderstandingKey : 'placeholder-value'
        }
        {
          name: 'content-understanding-api-versio' // Note: truncated to 32 chars
          value: !empty(contentUnderstandingApiVersion) ? contentUnderstandingApiVersion : 'placeholder-value'
        }
        {
          name: 'storage-account-api-key'
          value: !empty(storageAccountApiKey) ? storageAccountApiKey : 'placeholder-value'
        }
      ]
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
          {
            name: 'SERVICE_BUS_NAMESPACE'
            secretRef: 'service-bus-namespace'
          }
          {
            name: 'SERVICE_BUS_API_KEY'
            secretRef: 'service-bus-api-key'
          }
          {
            name: 'SERVICE_BUS_API_KEY_NAME'
            secretRef: 'service-bus-api-key-name'
          }
          {
            name: 'CONTENT_UNDERSTANDING_ENDPOINT'
            secretRef: 'content-understanding-endpoint'
          }
          {
            name: 'CONTENT_UNDERSTANDING_KEY'
            secretRef: 'content-understanding-key'
          }
          {
            name: 'CONTENT_UNDERSTANDING_API_VERSION'
            secretRef: 'content-understanding-api-versio'
          }
          {
            name: 'STORAGE_ACCOUNT_API_KEY'
            secretRef: 'storage-account-api-key'
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
      secureList: [
        {
          name: 'service-bus-namespace'
          value: !empty(serviceBusNamespace) ? serviceBusNamespace : 'placeholder-value'
        }
        {
          name: 'service-bus-api-key'
          value: !empty(serviceBusApiKey) ? serviceBusApiKey : 'placeholder-value'
        }
        {
          name: 'service-bus-api-key-name'
          value: !empty(serviceBusApiKeyName) ? serviceBusApiKeyName : 'placeholder-value'
        }
      ]
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
          {
            name: 'SERVICE_BUS_NAMESPACE'
            secretRef: 'service-bus-namespace'
          }
          {
            name: 'SERVICE_BUS_API_KEY'
            secretRef: 'service-bus-api-key'
          }
          {
            name: 'SERVICE_BUS_API_KEY_NAME'
            secretRef: 'service-bus-api-key-name'
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
      secureList: [
        {
          name: 'service-bus-namespace'
          value: !empty(serviceBusNamespace) ? serviceBusNamespace : 'placeholder-value'
        }
        {
          name: 'service-bus-api-key'
          value: !empty(serviceBusApiKey) ? serviceBusApiKey : 'placeholder-value'
        }
        {
          name: 'service-bus-api-key-name'
          value: !empty(serviceBusApiKeyName) ? serviceBusApiKeyName : 'placeholder-value'
        }
        {
          name: 'azure-openai-endpoint'
          value: !empty(azureOpenAIEndpoint) ? azureOpenAIEndpoint : 'placeholder-value'
        }
        {
          name: 'azure-openai-key'
          value: !empty(azureOpenAIKey) ? azureOpenAIKey : 'placeholder-value'
        }
        {
          name: 'azure-openai-api-version'
          value: !empty(azureOpenAIApiVersion) ? azureOpenAIApiVersion : 'placeholder-value'
        }
        {
          name: 'azure-openai-model-name'
          value: !empty(azureOpenAIModelName) ? azureOpenAIModelName : 'placeholder-value'
        }
        {
          name: 'content-understanding-endpoint'
          value: !empty(contentUnderstandingEndpoint) ? contentUnderstandingEndpoint : 'placeholder-value'
        }
        {
          name: 'content-understanding-key'
          value: !empty(contentUnderstandingKey) ? contentUnderstandingKey : 'placeholder-value'
        }
        {
          name: 'content-understanding-api-versio' // Note: truncated to 32 chars
          value: !empty(contentUnderstandingApiVersion) ? contentUnderstandingApiVersion : 'placeholder-value'
        }
        {
          name: 'storage-account-api-key'
          value: !empty(storageAccountApiKey) ? storageAccountApiKey : 'placeholder-value'
        }
      ]
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
          {
            name: 'SERVICE_BUS_NAMESPACE'
            secretRef: 'service-bus-namespace'
          }
          {
            name: 'SERVICE_BUS_API_KEY'
            secretRef: 'service-bus-api-key'
          }
          {
            name: 'SERVICE_BUS_API_KEY_NAME'
            secretRef: 'service-bus-api-key-name'
          }
          {
            name: 'AZURE_OPENAI_ENDPOINT'
            secretRef: 'azure-openai-endpoint'
          }
          {
            name: 'AZURE_OPENAI_KEY'
            secretRef: 'azure-openai-key'
          }
          {
            name: 'AZURE_OPENAI_API_VERSION'
            secretRef: 'azure-openai-api-version'
          }
          {
            name: 'AZURE_OPENAI_MODEL_NAME'
            secretRef: 'azure-openai-model-name'
          }
          {
            name: 'CONTENT_UNDERSTANDING_ENDPOINT'
            secretRef: 'content-understanding-endpoint'
          }
          {
            name: 'CONTENT_UNDERSTANDING_KEY'
            secretRef: 'content-understanding-key'
          }
          {
            name: 'CONTENT_UNDERSTANDING_API_VERSION'
            secretRef: 'content-understanding-api-versio'
          }
          {
            name: 'STORAGE_ACCOUNT_API_KEY'
            secretRef: 'storage-account-api-key'
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

// Deploy the Foundry Hub from the module
module foundryHub './modules/ai-services.bicep' = {
  name: 'foundry-hub'
  params: {
    location: location
    tags: tags
    foundryHubName:  '${abbrs.machineLearningServicesWorkspaces}${resourceToken}'
    containerRegistryResourceId: containerRegistry.outputs.resourceId
    applicationInsightsResourceId: monitoring.outputs.applicationInsightsResourceId
    keyVaultResourceId: keyVault.outputs.resourceId 
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_FOUNDRY_HUB_NAME string = foundryHub.outputs.name
output AZURE_FOUNDRY_HUB_ID string = foundryHub.outputs.resourceId
output AZURE_RESOURCE_CHUNK_VIDEO_CONTENT_ID string = chunkVideoContent.outputs.resourceId
output AZURE_RESOURCE_INDEX_FILE_API_ID string = indexFileApi.outputs.resourceId
output AZURE_RESOURCE_SUMMARIZE_VIDEO_CONTENT_ID string = summarizeVideoContent.outputs.resourceId
