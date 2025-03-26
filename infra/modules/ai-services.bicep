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

@description('Name of the AI Foundry Project')
param aiFoundryProjectName string = '${foundryHubName}-project'

@description('Display name for the AI Foundry Project')
param aiFoundryProjectDisplayName string = 'Video RAG AI Project'

@description('Abbreviations to use for resource naming')
param abbrs object

var keyVaultName = '${abbrs.keyVaultVaults}${resourceToken}-ai'

// Create a dedicated container registry for AI services
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'ai-services-registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}ai${resourceToken}'
    location: location
    tags: tags
    acrAdminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

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
    containerRegistry: containerRegistry.outputs.resourceId
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
      ApiVersion: '2023-05-15'
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

// User-assigned managed identity for the deployment script
resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-deploymentscript-${resourceToken}'
  location: location
  tags: tags
}

// Create role assignment for the deployment script identity to manage Cognitive Services
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploymentScriptIdentity.id, 'Contributor')
  scope: cognitiveServicesAccount
  properties: {
    principalId: deploymentScriptIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role
    principalType: 'ServicePrincipal'
  }
}

// Generate a unique token for resource naming
var resourceToken = uniqueString(subscription().id, resourceGroup().id, cognitiveServicesAccountName)

// Deployment script to deploy the GPT-4o model
resource deployGpt4oModel 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployGpt4oModel'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  dependsOn: [
    roleAssignment
    cognitiveServicesAccount
  ]
  properties: {
    azCliVersion: '2.69.0'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'COGNITIVE_ACCOUNT_NAME'
        value: cognitiveServicesAccountName
      }
      {
        name: 'DEPLOYMENT_NAME'
        value: gpt4oDeploymentName
      }
      {
        name: 'MODEL_NAME'
        value: gpt4oModelName
      }
      {
        name: 'MODEL_VERSION'
        value: gpt4oModelVersion
      }
      {
        name: 'CAPACITY'
        value: string(gpt4oCapacity)
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e
      
      # Login using the managed identity
      az login --identity
      
      # Check if deployment already exists
      EXISTING_DEPLOYMENT=$(az cognitiveservices account deployment list \
        --resource-group $RESOURCE_GROUP \
        --name $COGNITIVE_ACCOUNT_NAME \
        --query "[?name=='$DEPLOYMENT_NAME'].name" -o tsv)
      
      if [ -n "$EXISTING_DEPLOYMENT" ]; then
        echo "Deployment $DEPLOYMENT_NAME already exists."
      else
        echo "Creating new deployment $DEPLOYMENT_NAME with model $MODEL_NAME version $MODEL_VERSION..."
        
        az cognitiveservices account deployment create \
          --resource-group $RESOURCE_GROUP \
          --name $COGNITIVE_ACCOUNT_NAME \
          --deployment-name $DEPLOYMENT_NAME \
          --model-name $MODEL_NAME \
          --model-version $MODEL_VERSION \
          --model-format OpenAI \
          --sku Standard \
          --capacity $CAPACITY
        
        echo "Deployment completed successfully."
      fi
    '''
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
output containerRegistryName string = containerRegistry.outputs.name
