@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('API version for Content Understanding API')
param contentUnderstandingApiVersion string = '2023-05-01'

@description('API version for Azure OpenAI API')
param azureOpenaiApiVersion string = '2023-05-15'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)
var keyVaultName = '${abbrs.keyVaultVaults}${resourceToken}'

// Deploy core infrastructure (monitoring, container registry, container apps environment, key vault)
module coreInfra './modules/core-infrastructure.bicep' = {
  name: 'core-infrastructure'
  params: {
    location: location
    tags: tags
    keyVaultName: keyVaultName
  }
}

// Deploy Service Bus infrastructure
module serviceBusInfra './modules/service-bus.bicep' = {
  name: 'service-bus-infrastructure'
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    abbrs: abbrs
    keyVaultName: coreInfra.outputs.keyVaultName
  }
}

// Module for Service Bus key secrets 
module secrets './modules/secrets.bicep' = {
  name: 'service-bus-key-secrets'
  params: {
    keyVaultName: keyVaultName
    serviceBusNamespace: '${abbrs.serviceBusNamespaces}${resourceToken}'
    blobContainerName: coreInfra.outputs.blobContainerName
    storageAccountName: coreInfra.outputs.storageAccountName
  }
  dependsOn: [
    serviceBusInfra
  ]
}


var chunkVideoContentSecrets = {
  secrets : [
    {
      name: 'service-bus-namespace'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-namespace'
    }
    {
      name: 'service-bus-api-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-key'
    }
    {
      name: 'service-bus-api-key-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-api-key-name'
    }
    {
      name: 'index-file-queue'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/index-file-queue-name'
    }
    {
      name: 'finalize-content-queue'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/finalize-content-queue-name'
    }
    {
      name: 'content-understanding-endpoint'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/content-understanding-endpoint'
    }
    {
      name: 'content-understanding-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/content-understanding-key'
    }
    {
      name: 'content-understanding-api-version'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/content-understanding-api-version'
    }
    {
      name: 'storage-account-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/storage-account-name'
    }
    {
      name: 'storage-container-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/container-name'
    }
    {
      name: 'storage-account-api-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/storage-account-api-key'
    }
  ]
}

var indexFileApiSecrets = {
  secrets : [
    {
      name: 'service-bus-namespace'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-namespace'
    }
    {
      name: 'service-bus-api-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-key'
    }
    {
      name: 'service-bus-api-key-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-api-key-name'
    }
    {
      name: 'index-file-queue'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/index-file-queue-name'
    }
  ]
}

var summarizeVideoContentSecrets = {
  secrets : [
    {
      name: 'service-bus-namespace'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-namespace'
    }
    {
      name: 'service-bus-api-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-key'
    }
    {
      name: 'service-bus-api-key-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/service-bus-api-key-name'
    }
    {
      name: 'finalize-content-queue'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/finalize-content-queue-name'
    }
    {
      name: 'video-summary-queue'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/video-summary-queue-name'
    }
    {
      name: 'azure-openai-endpoint'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/open-ai-endpoint'
    }
    {
      name: 'azure-openai-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/open-ai-key'
    }
    {
      name: 'azure-openai-api-version'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/azure-openai-api-version'
    }
    {
      name: 'azure-openai-model-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/open-ai-deployment-name'
    }
    {
      name: 'content-understanding-endpoint'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/content-understanding-endpoint'
    }
    {
      name: 'content-understanding-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/content-understanding-key'
    }
    {
      name: 'content-understanding-api-version'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/content-understanding-api-version'
    }
    {
      name: 'storage-account-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/storage-account-name'
    }
    {
      name: 'storage-container-name'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/container-name'
    }
    {
      name: 'storage-account-api-key'
      keyVaultUrl: '${coreInfra.outputs.keyVaultUri}secrets/storage-account-api-key'
    }
  ]
}

// Define environment variables by service
var chunkVideoContentEnvVars = [
  { name: 'SERVICE_BUS_NAMESPACE', secretRef: 'service-bus-namespace' }
  { name: 'SERVICE_BUS_API_KEY', secretRef: 'service-bus-api-key' }
  { name: 'SERVICE_BUS_API_KEY_NAME', secretRef: 'service-bus-api-key-name' }
  { name: 'INDEX_FILE_QUEUE', secretRef: 'index-file-queue' }
  { name: 'FINALIZE_CONTENT_QUEUE', secretRef: 'finalize-content-queue' }
  { name: 'CONTENT_UNDERSTANDING_ENDPOINT', secretRef: 'content-understanding-endpoint' }
  { name: 'CONTENT_UNDERSTANDING_KEY', secretRef: 'content-understanding-key' }
  { name: 'CONTENT_UNDERSTANDING_API_VERSION', secretRef: 'content-understanding-api-version' }
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
  { name: 'CONTENT_UNDERSTANDING_API_VERSION', secretRef: 'content-understanding-api-version' }
  { name: 'STORAGE_ACCOUNT_NAME', secretRef: 'storage-account-name' }
  { name: 'STORAGE_CONTAINER_NAME', secretRef: 'storage-container-name' }
  { name: 'STORAGE_ACCOUNT_API_KEY', secretRef: 'storage-account-api-key' }
]

// Deploy individual container apps - we need to deploy in two steps
// First, deploy the app to get the identity ID
module chunkVideoContentApp './app-modules/chunk-video-content.bicep' = {
  name: 'chunk-video-content-app'
  params: {
    location: location
    tags: tags
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    chunkVideoContentSecrets: chunkVideoContentSecrets
    chunkVideoContentEnvVars: chunkVideoContentEnvVars
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    storageAccountName: coreInfra.outputs.storageAccountName
    blobContainerName: coreInfra.outputs.blobContainerName
    abbrs: abbrs
    resourceToken: resourceToken
    keyVaultName: coreInfra.outputs.keyVaultName
  }
  dependsOn: [
    secrets
  ]
}

// First, deploy the app to get the identity ID
module indexFileApiApp './app-modules/index-file-api.bicep' = {
  name: 'index-file-api-app'
  params: {
    location: location
    tags: tags
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    indexFileApiSecrets: indexFileApiSecrets
    indexFileApiEnvVars: indexFileApiEnvVars
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    abbrs: abbrs
    resourceToken: resourceToken
    keyVaultName: coreInfra.outputs.keyVaultName
  }
  dependsOn: [
    secrets
  ]
}

// First, deploy the app to get the identity ID
module summarizeVideoContentApp './app-modules/summarize-video-content.bicep' = {
  name: 'summarize-video-content-app'
  params: {
    location: location
    tags: tags
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    summarizeVideoContentSecrets: summarizeVideoContentSecrets
    summarizeVideoContentEnvVars: summarizeVideoContentEnvVars
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    storageAccountName: coreInfra.outputs.storageAccountName
    blobContainerName: coreInfra.outputs.blobContainerName
    abbrs: abbrs
    resourceToken: resourceToken
    keyVaultName: coreInfra.outputs.keyVaultName
  }
  dependsOn: [
    secrets
  ]
}

// Deploy the Foundry Hub from the module
module aiServices './modules/ai-services.bicep' = {
  name: 'ai-services'
  params: {
    location: location
    tags: tags
    foundryHubName: '${abbrs.machineLearningServicesWorkspaces}${resourceToken}'
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    keyVaultResourceId: coreInfra.outputs.keyVaultResourceId
    keyVaultName: coreInfra.outputs.keyVaultName
    cognitiveServicesAccountName: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    gpt4oDeploymentName: 'gpt-4o'
    gpt4oModelName: 'gpt-4o'
    gpt4oModelVersion: '2024-05-13'
    aiFoundryProjectName: '${abbrs.machineLearningServicesWorkspaces}${resourceToken}-project'
    aiFoundryProjectDisplayName: 'Video RAG Pipeline Project'
    abbrs: abbrs
    contentUnderstandingApiVersion: contentUnderstandingApiVersion
    azureOpenaiApiVersion: azureOpenaiApiVersion
  }
}

// Deploy Content Understanding Schema and Analyzer setup
module contentUnderstandingSetup './modules/content-understanding-setup.bicep' = {
  name: 'content-understanding-setup'
  params: {
    location: location
    tags: tags
    cognitiveServicesAccountName: aiServices.outputs.cognitiveServicesAccountName
    contentUnderstandingEndpoint: aiServices.outputs.cognitiveServicesEndpoint
    contentUnderstandingKey: aiServices.outputs.contentUnderstandingEndpoint
    resourceToken: resourceToken
    analyzerName: 'video-content-analyzer'
  }
}

// Add new outputs for Content Understanding
output AZURE_CONTENT_UNDERSTANDING_ANALYZER string = contentUnderstandingSetup.outputs.analyzerName

output AZURE_KEY_VAULT_ENDPOINT string = coreInfra.outputs.keyVaultUri
output AZURE_KEY_VAULT_NAME string = coreInfra.outputs.keyVaultName
output AZURE_FOUNDRY_HUB_NAME string = aiServices.outputs.name
output AZURE_FOUNDRY_HUB_ID string = aiServices.outputs.resourceId
output AZURE_FOUNDRY_PROJECT_NAME string = aiServices.outputs.aiProjectName
output AZURE_FOUNDRY_PROJECT_ID string = aiServices.outputs.aiProjectId
output AZURE_AI_SERVICE_CONNECTION_NAME string = aiServices.outputs.aiServiceConnectionName
output AZURE_AI_SERVICE_CONNECTION_ID string = aiServices.outputs.aiServiceConnectionId
output AZURE_COGNITIVE_SERVICES_NAME string = aiServices.outputs.cognitiveServicesAccountName
output AZURE_COGNITIVE_SERVICES_ID string = aiServices.outputs.cognitiveServicesAccountId
output AZURE_COGNITIVE_SERVICES_ENDPOINT string = aiServices.outputs.cognitiveServicesEndpoint
output AZURE_GPT4O_DEPLOYMENT_NAME string = aiServices.outputs.gpt4oDeploymentName
output AZURE_SERVICE_BUS_NAMESPACE string = serviceBusInfra.outputs.serviceBusNamespaceName
output AZURE_SERVICE_BUS_ENDPOINT string = serviceBusInfra.outputs.serviceBusEndpoint
output AZURE_INDEX_FILE_QUEUE string = serviceBusInfra.outputs.indexFileQueueName
output AZURE_FINALIZE_CONTENT_QUEUE string = serviceBusInfra.outputs.finalizeContentQueueName
output AZURE_VIDEO_SUMMARY_QUEUE string = serviceBusInfra.outputs.videoSummaryQueueName
output AZURE_STORAGE_ACCOUNT_NAME string = coreInfra.outputs.storageAccountName
output AZURE_STORAGE_CONTAINER_NAME string = coreInfra.outputs.blobContainerName
