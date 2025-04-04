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

// Deploy core infrastructure (monitoring, container registry, container apps environment, key vault)
module coreInfra './modules/core-infrastructure.bicep' = {
  name: 'core-infrastructure'
  params: {
    location: location
    tags: tags
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
  }
}

// Deploy individual container apps
module chunkVideoContentApp './app-modules/chunk-video-content/app.bicep' = {
  name: 'chunk-video-content-app'
  params: {
    location: location
    tags: tags
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    storageAccountName: coreInfra.outputs.storageAccountName
    blobContainerName: coreInfra.outputs.blobContainerName
    cognitiveServicesAccountName: aiServices.outputs.cognitiveServicesAccountName
    containerRegistryLoginServer: coreInfra.outputs.containerRegistryLoginServer
    containerRegistryName: coreInfra.outputs.containerRegistryName
    abbrs: abbrs
    resourceToken: resourceToken
  }
}

module indexFileApiApp './app-modules/index-file-api/app.bicep' = {
  name: 'index-file-api-app'
  params: {
    location: location
    tags: tags
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    storageAccountNameParam: coreInfra.outputs.storageAccountName
    blobContainerNameParam: coreInfra.outputs.blobContainerName
    containerRegistryLoginServer: coreInfra.outputs.containerRegistryLoginServer
    containerRegistryName: coreInfra.outputs.containerRegistryName
    abbrs: abbrs
    resourceToken: resourceToken
  }
}

module summarizeVideoContentApp './app-modules/summarize-video-content/app.bicep' = {
  name: 'summarize-video-content-app'
  params: {
    location: location
    tags: tags
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    containerAppsEnvironmentResourceId: coreInfra.outputs.containerAppsEnvironmentResourceId
    serviceBusNamespaceName: serviceBusInfra.outputs.serviceBusNamespaceName
    storageAccountName: coreInfra.outputs.storageAccountName
    blobContainerName: coreInfra.outputs.blobContainerName
    cognitiveServicesAccountName: aiServices.outputs.cognitiveServicesAccountName
    openAiDeploymentName: aiServices.outputs.gpt4oDeploymentName
    containerRegistryLoginServer: coreInfra.outputs.containerRegistryLoginServer
    containerRegistryName: coreInfra.outputs.containerRegistryName
    abbrs: abbrs
    resourceToken: resourceToken
  }
}

// Deploy the Foundry Hub from the module
module aiServices './modules/ai-services.bicep' = {
  name: 'ai-services'
  params: {
    location: location
    tags: tags
    foundryHubName: '${abbrs.machineLearningServicesWorkspaces}${resourceToken}'
    applicationInsightsResourceId: coreInfra.outputs.applicationInsightsResourceId
    cognitiveServicesAccountName: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    gpt4oDeploymentName: 'gpt-4o'
    gpt4oModelName: 'gpt-4o'
    gpt4oModelVersion: '2024-05-13'
    ApiVersion: azureOpenaiApiVersion
    aiFoundryProjectName: '${abbrs.machineLearningServicesWorkspaces}${resourceToken}-project'
    aiFoundryProjectDisplayName: 'Video RAG Pipeline Project'
    containerRegistryResourceId: coreInfra.outputs.containerRegistryResourceId
    abbrs: abbrs
  }
}

// Deploy Content Understanding Schema and Analyzer setup
module contentUnderstandingSetup './modules/content-understanding-setup.bicep' = {
  name: 'content-understanding-setup'
  params: {
    location: location
    tags: tags
    cognitiveServicesAccountName: aiServices.outputs.cognitiveServicesAccountName
    contentUnderstandingEndpoint: aiServices.outputs.contentUnderstandingEndpoint
    contentUnderstandingKey: aiServices.outputs.cognitiveServicesEndpoint  // BUG: Wrong parameter passed
    resourceToken: resourceToken
    analyzerName: 'video-content-analyzer'
    apiVersion: contentUnderstandingApiVersion
  }
  dependsOn: [
    aiServices
  ]
}

// Add new outputs for Content Understanding
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
