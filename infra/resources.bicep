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

// Deploy managed identities for container apps (must deploy first to use in core infrastructure)
module identities './modules/managed-identities.bicep' = {
  name: 'managed-identities'
  params: {
    location: location
    resourceToken: resourceToken
    abbrs: abbrs
  }
}

// Deploy core infrastructure (monitoring, container registry, container apps environment, key vault)
module coreInfra './modules/core-infrastructure.bicep' = {
  name: 'core-infrastructure'
  params: {
    location: location
    tags: tags
    managedIdentityPrincipalIds: identities.outputs.managedIdentityPrincipalIds
    principalId: principalId
  }
}

// Deploy Service Bus infrastructure
module serviceBusInfra './modules/service-bus.bicep' = {
  name: 'service-bus-infrastructure'
  params: {
    location: location
    tags: tags
    managedIdentityPrincipalIds: identities.outputs.managedIdentityPrincipalIds
    resourceToken: resourceToken
    abbrs: abbrs
  }
}

// Define secrets by group
var serviceBusSecrets = [
  { name: 'service-bus-namespace', value: serviceBusInfra.outputs.serviceBusEndpoint }
  { name: 'service-bus-api-key', value: !empty(serviceBusApiKey) ? serviceBusApiKey : 'placeholder-value' }
  { name: 'service-bus-api-key-name', value: !empty(serviceBusApiKeyName) ? serviceBusApiKeyName : 'placeholder-value' }
  { name: 'index-file-queue', value: serviceBusInfra.outputs.indexFileQueueName }
  { name: 'finalize-content-queue', value: serviceBusInfra.outputs.finalizeContentQueueName }
  { name: 'video-summary-queue', value: serviceBusInfra.outputs.videoSummaryQueueName }
]

var contentSecrets = [
  { name: 'content-understanding-endpoint', value: !empty(contentUnderstandingEndpoint) ? contentUnderstandingEndpoint : 'placeholder-value' }
  { name: 'content-understanding-key', value: !empty(contentUnderstandingKey) ? contentUnderstandingKey : 'placeholder-value' }
  { name: 'content-understanding-api-versio', value: !empty(contentUnderstandingApiVersion) ? contentUnderstandingApiVersion : 'placeholder-value' }
]

var openAISecrets = [
  { name: 'azure-openai-endpoint', value: !empty(azureOpenAIEndpoint) ? azureOpenAIEndpoint : 'placeholder-value' }
  { name: 'azure-openai-key', value: !empty(azureOpenAIKey) ? azureOpenAIKey : 'placeholder-value' }
  { name: 'azure-openai-api-version', value: !empty(azureOpenAIApiVersion) ? azureOpenAIApiVersion : 'placeholder-value' }
  { name: 'azure-openai-model-name', value: !empty(azureOpenAIModelName) ? azureOpenAIModelName : 'placeholder-value' }
]

var storageSecrets = [
  { name: 'storage-account-api-key', value: !empty(storageAccountApiKey) ? storageAccountApiKey : 'placeholder-value' }
  { name: 'storage-account-name', value: coreInfra.outputs.storageAccountName }
  { name: 'storage-container-name', value: coreInfra.outputs.blobContainerName }
]

// Combine secrets by service
var chunkVideoContentSecrets = concat(serviceBusSecrets, contentSecrets, storageSecrets)
var indexFileApiSecrets = serviceBusSecrets
var summarizeVideoContentSecrets = concat(serviceBusSecrets, openAISecrets, contentSecrets, storageSecrets)

// Define environment variables by service
var chunkVideoContentEnvVars = [
  { name: 'SERVICE_BUS_NAMESPACE', secretRef: 'service-bus-namespace' }
  { name: 'SERVICE_BUS_API_KEY', secretRef: 'service-bus-api-key' }
  { name: 'SERVICE_BUS_API_KEY_NAME', secretRef: 'service-bus-api-key-name' }
  { name: 'INDEX_FILE_QUEUE', secretRef: 'index-file-queue' }
  { name: 'FINALIZE_CONTENT_QUEUE', secretRef: 'finalize-content-queue' }
  { name: 'CONTENT_UNDERSTANDING_ENDPOINT', secretRef: 'content-understanding-endpoint' }
  { name: 'CONTENT_UNDERSTANDING_KEY', secretRef: 'content-understanding-key' }
  { name: 'CONTENT_UNDERSTANDING_API_VERSION', secretRef: 'content-understanding-api-versio' }
  { name: 'STORAGE_ACCOUNT_NAME', secretRef: 'storage-account-name' }
  { name: 'STORAGE_CONTAINER_NAME', secretRef: 'storage-container-name' }
  { name: 'STORAGE_ACCOUNT_API_KEY', secretRef: 'storage-account-api-key' }
]

var indexFileApiEnvVars = [
  { name: 'SERVICE_BUS_NAMESPACE', secretRef: 'service-bus-namespace' }
  { name: 'SERVICE_BUS_API_KEY', secretRef: 'service-bus-api-key' }
  { name: 'SERVICE_BUS_API_KEY_NAME', secretRef: 'service-bus-api-key-name' }
  { name: 'INDEX_FILE_QUEUE', secretRef: 'index-file-queue' }
]

var summarizeVideoContentEnvVars = [
  { name: 'SERVICE_BUS_NAMESPACE', secretRef: 'service-bus-namespace' }
  { name: 'SERVICE_BUS_API_KEY', secretRef: 'service-bus-api-key' }
  { name: 'SERVICE_BUS_API_KEY_NAME', secretRef: 'service-bus-api-key-name' }
  { name: 'FINALIZE_CONTENT_QUEUE', secretRef: 'finalize-content-queue' }
  { name: 'VIDEO_SUMMARY_QUEUE', secretRef: 'video-summary-queue' }
  { name: 'AZURE_OPENAI_ENDPOINT', secretRef: 'azure-openai-endpoint' }
  { name: 'AZURE_OPENAI_KEY', secretRef: 'azure-openai-key' }
  { name: 'AZURE_OPENAI_API_VERSION', secretRef: 'azure-openai-api-version' }
  { name: 'AZURE_OPENAI_MODEL_NAME', secretRef: 'azure-openai-model-name' }
  { name: 'CONTENT_UNDERSTANDING_ENDPOINT', secretRef: 'content-understanding-endpoint' }
  { name: 'CONTENT_UNDERSTANDING_KEY', secretRef: 'content-understanding-key' }
  { name: 'CONTENT_UNDERSTANDING_API_VERSION', secretRef: 'content-understanding-api-versio' }
  { name: 'STORAGE_ACCOUNT_NAME', secretRef: 'storage-account-name' }
  { name: 'STORAGE_CONTAINER_NAME', secretRef: 'storage-container-name' }
  { name: 'STORAGE_ACCOUNT_API_KEY', secretRef: 'storage-account-api-key' }
]

// Deploy individual container apps
module chunkVideoContentApp './app-modules/chunk-video-content.bicep' = {
  name: 'chunk-video-content-app'
  params: {
    location: location
    tags: tags
    applicationInsightsConnectionString: coreInfra.outputs.applicationInsightsConnectionString
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    containerRegistryLoginServer: coreInfra.outputs.containerRegistryLoginServer
    chunkVideoContentExists: chunkVideoContentExists
    chunkVideoContentDefinition: chunkVideoContentDefinition
    chunkVideoContentIdentityResourceId: identities.outputs.chunkVideoContentIdentityResourceId
    chunkVideoContentIdentityClientId: identities.outputs.chunkVideoContentIdentityClientId
    chunkVideoContentSecrets: chunkVideoContentSecrets
    chunkVideoContentEnvVars: chunkVideoContentEnvVars
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    storageAccountName: coreInfra.outputs.storageAccountName
    blobContainerName: coreInfra.outputs.blobContainerName
  }
}

module indexFileApiApp './app-modules/index-file-api.bicep' = {
  name: 'index-file-api-app'
  params: {
    location: location
    tags: tags
    applicationInsightsConnectionString: coreInfra.outputs.applicationInsightsConnectionString
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    containerRegistryLoginServer: coreInfra.outputs.containerRegistryLoginServer
    indexFileApiExists: indexFileApiExists
    indexFileApiDefinition: indexFileApiDefinition
    indexFileApiIdentityResourceId: identities.outputs.indexFileApiIdentityResourceId
    indexFileApiIdentityClientId: identities.outputs.indexFileApiIdentityClientId
    indexFileApiSecrets: indexFileApiSecrets
    indexFileApiEnvVars: indexFileApiEnvVars
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
  }
}

module summarizeVideoContentApp './app-modules/summarize-video-content.bicep' = {
  name: 'summarize-video-content-app'
  params: {
    location: location
    tags: tags
    applicationInsightsConnectionString: coreInfra.outputs.applicationInsightsConnectionString
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    containerRegistryLoginServer: coreInfra.outputs.containerRegistryLoginServer
    summarizeVideoContentExists: summarizeVideoContentExists
    summarizeVideoContentDefinition: summarizeVideoContentDefinition
    summarizeVideoContentIdentityResourceId: identities.outputs.summarizeVideoContentIdentityResourceId
    summarizeVideoContentIdentityClientId: identities.outputs.summarizeVideoContentIdentityClientId
    summarizeVideoContentSecrets: summarizeVideoContentSecrets
    summarizeVideoContentEnvVars: summarizeVideoContentEnvVars
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    storageAccountName: coreInfra.outputs.storageAccountName
    blobContainerName: coreInfra.outputs.blobContainerName
  }
}

// Deploy the Foundry Hub from the module
module aiServices './modules/ai-services.bicep' = {
  name: 'ai-services'
  params: {
    location: location
    tags: tags
    foundryHubName: '${abbrs.machineLearningServicesWorkspaces}${resourceToken}'
    containerRegistryResourceId: coreInfra.outputs.containerRegistryResourceId
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    keyVaultResourceId: coreInfra.outputs.keyVaultResourceId
    keyVaultName: coreInfra.outputs.keyVaultName
    cognitiveServicesAccountName: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    gpt4oDeploymentName: 'gpt-4o'
    gpt4oModelName: 'gpt-4o'
    gpt4oModelVersion: '2024-05-13'
    aiFoundryProjectName: '${abbrs.machineLearningServicesWorkspaces}${resourceToken}-project'
    aiFoundryProjectDisplayName: 'Video RAG Pipeline Project'
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = coreInfra.outputs.containerRegistryLoginServer
output AZURE_KEY_VAULT_ENDPOINT string = coreInfra.outputs.keyVaultUri
output AZURE_KEY_VAULT_NAME string = coreInfra.outputs.keyVaultName
output AZURE_FOUNDRY_HUB_NAME string = aiServices.outputs.name
output AZURE_FOUNDRY_HUB_ID string = aiServices.outputs.resourceId
output AZURE_FOUNDRY_PROJECT_NAME string = aiServices.outputs.aiProjectName
output AZURE_FOUNDRY_PROJECT_ID string = aiServices.outputs.aiProjectId
//output AZURE_AI_SERVICE_CONNECTION_NAME string = aiServices.outputs.aiServiceConnectionName
//output AZURE_AI_SERVICE_CONNECTION_ID string = aiServices.outputs.aiServiceConnectionId
output AZURE_COGNITIVE_SERVICES_NAME string = aiServices.outputs.cognitiveServicesAccountName
output AZURE_COGNITIVE_SERVICES_ID string = aiServices.outputs.cognitiveServicesAccountId
output AZURE_COGNITIVE_SERVICES_ENDPOINT string = aiServices.outputs.cognitiveServicesEndpoint
output AZURE_GPT4O_DEPLOYMENT_NAME string = aiServices.outputs.gpt4oDeploymentName
output AZURE_RESOURCE_CHUNK_VIDEO_CONTENT_ID string = chunkVideoContentApp.outputs.resourceId
output AZURE_RESOURCE_INDEX_FILE_API_ID string = indexFileApiApp.outputs.resourceId
output AZURE_RESOURCE_SUMMARIZE_VIDEO_CONTENT_ID string = summarizeVideoContentApp.outputs.resourceId
output AZURE_SERVICE_BUS_NAMESPACE string = serviceBusInfra.outputs.serviceBusNamespaceName
output AZURE_SERVICE_BUS_ENDPOINT string = serviceBusInfra.outputs.serviceBusEndpoint
output AZURE_INDEX_FILE_QUEUE string = serviceBusInfra.outputs.indexFileQueueName
output AZURE_FINALIZE_CONTENT_QUEUE string = serviceBusInfra.outputs.finalizeContentQueueName
output AZURE_VIDEO_SUMMARY_QUEUE string = serviceBusInfra.outputs.videoSummaryQueueName
output AZURE_STORAGE_ACCOUNT_NAME string = coreInfra.outputs.storageAccountName
output AZURE_STORAGE_CONTAINER_NAME string = coreInfra.outputs.blobContainerName
