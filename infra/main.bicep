targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Service Bus API Key')
@secure()
param serviceBusApiKey string = ''

@description('Service Bus API Key Name')
param serviceBusApiKeyName string = ''

// Setting default values for Content Understanding parameters
@description('Content Understanding Endpoint')
param contentUnderstandingEndpoint string = ''

@description('Content Understanding Key')
@secure()
param contentUnderstandingKey string = ''

@description('Content Understanding API Version')
param contentUnderstandingApiVersion string = ''

// Setting default values for Azure OpenAI parameters
@description('Azure OpenAI Endpoint')
param azureOpenAIEndpoint string = ''

@description('Azure OpenAI Key')
@secure()
param azureOpenAIKey string = ''

@description('Azure OpenAI API Version')
param azureOpenAIApiVersion string = ''

@description('Azure OpenAI Model Name')
param azureOpenAIModelName string = ''

// Setting default value for Storage Account API Key
@description('Storage Account API Key')
@secure()
param storageAccountApiKey string = ''

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

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    chunkVideoContentExists: chunkVideoContentExists
    chunkVideoContentDefinition: chunkVideoContentDefinition
    indexFileApiExists: indexFileApiExists
    indexFileApiDefinition: indexFileApiDefinition
    summarizeVideoContentExists: summarizeVideoContentExists
    summarizeVideoContentDefinition: summarizeVideoContentDefinition
    // Pass the parameters to resources.bicep
    serviceBusApiKey: serviceBusApiKey
    serviceBusApiKeyName: serviceBusApiKeyName
    contentUnderstandingEndpoint: contentUnderstandingEndpoint
    contentUnderstandingKey: contentUnderstandingKey
    contentUnderstandingApiVersion: contentUnderstandingApiVersion
    azureOpenAIEndpoint: azureOpenAIEndpoint
    azureOpenAIKey: azureOpenAIKey
    azureOpenAIApiVersion: azureOpenAIApiVersion
    azureOpenAIModelName: azureOpenAIModelName
    storageAccountApiKey: storageAccountApiKey
  }
}

output AZURE_KEY_VAULT_ENDPOINT string = resources.outputs.AZURE_KEY_VAULT_ENDPOINT
output AZURE_KEY_VAULT_NAME string = resources.outputs.AZURE_KEY_VAULT_NAME
output AZURE_RESOURCE_CHUNK_VIDEO_CONTENT_ID string = resources.outputs.AZURE_RESOURCE_CHUNK_VIDEO_CONTENT_ID
output AZURE_RESOURCE_INDEX_FILE_API_ID string = resources.outputs.AZURE_RESOURCE_INDEX_FILE_API_ID
output AZURE_RESOURCE_SUMMARIZE_VIDEO_CONTENT_ID string = resources.outputs.AZURE_RESOURCE_SUMMARIZE_VIDEO_CONTENT_ID
