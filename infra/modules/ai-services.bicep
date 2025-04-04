@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Name of the Foundry Hub')
param foundryHubName string = 'foundryHub'

@description('Resource ID of the Application Insights instance')
param applicationInsightsResourceId string

@description('Name of the Cognitive Services account')
param cognitiveServicesAccountName string = foundryHubName

@description('Name of the GPT-4o model deployment')
param gpt4oDeploymentName string = 'gpt-4o'

@description('GPT-4o model name')
param gpt4oModelName string = 'gpt-4o'

@description('GPT-4o model version')
param gpt4oModelVersion string = '2024-05-13'

@description('Capacity for the GPT-4o model deployment')
param gpt4oCapacity int = 1

@description('SKU for the OpenAI model deployment')
param openAiSkuName string = 'Standard'

@description('Format for the OpenAI model deployment')
param openAiModelFormat string = 'OpenAI'

@description('Name of the AI Foundry Project')
param aiFoundryProjectName string = '${foundryHubName}-project'

@description('Display name for the AI Foundry Project')
param aiFoundryProjectDisplayName string = 'Video RAG AI Project'

@description('Resource ID of the Container Registry')
param containerRegistryResourceId string

@description('Abbreviations to use for resource naming')
param abbrs object

@description('API version for Azure OpenAI API')
param ApiVersion string = '2023-05-15'

var keyVaultName = '${abbrs.keyVaultVaults}${resourceToken}-ai'

// Create the AI Foundry Hub
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2023-08-01-preview' = {
  name: foundryHubName
  location: location
  kind: 'hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Azure AI Foundry Hub'
    friendlyName: 'AI Foundry Hub'
    publicNetworkAccess: 'Enabled'
    containerRegistry: containerRegistryResourceId
    applicationInsights: applicationInsightsResourceId
    keyVault: keyVault.outputs.resourceId
  }
  tags: tags
}

// Create the AI Foundry Project
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2023-08-01-preview' = {
  name: aiFoundryProjectName
  location: location
  kind: 'project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'AI Foundry Project for Video RAG'
    friendlyName: aiFoundryProjectDisplayName
    hubResourceId: aiHub.id
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

// Connect the Azure OpenAI endpoint to the AI Foundry Project
resource aiServiceConnection 'Microsoft.MachineLearningServices/workspaces/connections@2023-08-01-preview' = {
  parent: aiProject
  name: 'openai-connection'
  properties: {
    category: 'AzureOpenAI'
    target: cognitiveServicesAccount.properties.endpoint
    authType: 'ApiKey'
    isSharedToAll: false
    credentials: {
      key: cognitiveServicesAccount.listKeys().key1
    }
    metadata: {
      resourceName: cognitiveServicesAccount.name
      ApiType: 'ApiKey'
      ApiVersion: ApiVersion
      Kind: 'OpenAI'
      AuthType: 'ApiKey'
    }
  }
}

// Add Cognitive Services account of kind AIServices
resource cognitiveServicesAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: cognitiveServicesAccountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: cognitiveServicesAccountName
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
  }
}

var contentUnderstandingEndpoint = 'https://${cognitiveServicesAccountName}.services.ai.azure.com/'

// Generate a unique token for resource naming
var resourceToken = uniqueString(subscription().id, resourceGroup().id, cognitiveServicesAccountName)

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: cognitiveServicesAccount
  name: gpt4oDeploymentName
  sku: {
    capacity: gpt4oCapacity
    name: openAiSkuName
  }    
  properties: {
    model: {
      format: openAiModelFormat
      name: gpt4oModelName
      version: gpt4oModelVersion
    }
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: keyVaultName
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enableRbacAuthorization: true
  }
}

// Deploy Content Understanding Schema and Analyzer setup
module contentUnderstandingSetup 'content-understanding-setup.bicep' = {
  name: 'content-understanding-setup'
  params: {
    location: location
    tags: tags
    cognitiveServicesAccountName: cognitiveServicesAccount.name
    contentUnderstandingEndpoint: contentUnderstandingEndpoint
    contentUnderstandingKey: cognitiveServicesAccount.listKeys().key1
    resourceToken: resourceToken
    analyzerName: 'video-content-analyzer'
  }
}

output cognitiveServicesAccountName string = cognitiveServicesAccount.name
output cognitiveServicesAccountId string = cognitiveServicesAccount.id
output cognitiveServicesEndpoint string = cognitiveServicesAccount.properties.endpoint
output contentUnderstandingEndpoint string = contentUnderstandingEndpoint
output gpt4oDeploymentName string = gpt4oDeploymentName
output aiProjectName string = aiProject.name
output aiProjectId string = aiProject.id
output aiProjectPrincipalId string = aiProject.identity.principalId
output aiServiceConnectionName string = aiServiceConnection.name
output aiServiceConnectionId string = aiServiceConnection.id
output resourceId string = aiHub.id
output name string = aiHub.name
output principalId string = aiHub.identity.principalId
