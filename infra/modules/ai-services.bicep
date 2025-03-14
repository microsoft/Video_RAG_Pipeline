@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Name of the Foundry Hub')
param foundryHubName string = 'foundryHub'

@description('Resource ID of the container registry')
param containerRegistryResourceId string

@description('Resource ID of the Application Insights instance')
param applicationInsightsResourceId string

@description('Resource ID of the Key Vault')
param keyVaultResourceId string

<<<<<<< Updated upstream
=======
@description('Name of the Key Vault for storing secrets')
param keyVaultName string

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

>>>>>>> Stashed changes
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
    keyVault: keyVaultResourceId
  }
  tags: tags
}

<<<<<<< Updated upstream
output resourceId string = aiHub.id
output name string = aiHub.name
output principalId string = aiHub.identity.principalId
=======
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

// Reference to the Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// Store the Cognitive Services primary key in Key Vault
resource cognitiveServicesPrimaryKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'cognitive-services-primary-key'
  properties: {
    value: cognitiveServicesAccount.listKeys().key1
  }
}

// Store the Cognitive Services secondary key in Key Vault
resource cognitiveServicesSecondaryKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'cognitive-services-secondary-key'
  properties: {
    value: cognitiveServicesAccount.listKeys().key2
  }
}

// Store the Cognitive Services endpoint in Key Vault
resource cognitiveServicesEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'cognitive-services-endpoint'
  properties: {
    value: cognitiveServicesAccount.properties.endpoint
  }
}

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

output resourceId string = aiHub.id
output name string = aiHub.name
output principalId string = aiHub.identity.principalId
output cognitiveServicesAccountName string = cognitiveServicesAccount.name
output cognitiveServicesAccountId string = cognitiveServicesAccount.id
output cognitiveServicesEndpoint string = cognitiveServicesAccount.properties.endpoint
output gpt4oDeploymentName string = gpt4oDeploymentName
>>>>>>> Stashed changes
