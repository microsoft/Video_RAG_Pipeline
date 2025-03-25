@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Endpoint URL of the Cognitive Services account')
param contentUnderstandingEndpoint string

@description('API key for the Cognitive Services account')
@secure()
param contentUnderstandingKey string

@description('Resource token for unique resource naming')
param resourceToken string

@description('Name of the Content Understanding analyzer to create')
param analyzerName string = 'video-content-analyzer'

@description('The name of the Cognitive Services account')
param cognitiveServicesAccountName string

var analyzerFilePath = '../schemas/content-analyzer.json'

// Load analyzer definition from JSON file
var analyzerDefinition = loadJsonContent(analyzerFilePath)

// User-assigned managed identity for the deployment script
resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-contentunderstanding-${resourceToken}'
  location: location
  tags: tags
}

// Reference to the Cognitive Services account
resource cognitiveService 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: cognitiveServicesAccountName
}

// Create a completely unique role assignment ID that won't conflict
var roleGuid = guid('cognitive-services-contributor', resourceGroup().id, deploymentScriptIdentity.id, cognitiveServicesAccountName, resourceToken)

// Create role assignment for the deployment script identity to manage Cognitive Services
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleGuid
  scope: cognitiveService
  properties: {
    principalId: deploymentScriptIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68') // Cognitive Services Contributor
    principalType: 'ServicePrincipal'
    description: 'Grant Content Understanding setup script permission to manage Cognitive Services'
  }
}

// Deployment script to create the analyzer
resource contentUnderstandingSetup 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployContentUnderstanding'
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
  ]
  properties: {
    azCliVersion: '2.69.0'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'ANALYZER_NAME'
        value: analyzerName
      }
      {
        name: 'ANALYZER_CONTENT'
        value: string(analyzerDefinition)
      }
      {
        name: 'CONTENT_UNDERSTANDING_ENDPOINT'
        value: contentUnderstandingEndpoint
      }
      {
        name: 'CONTENT_UNDERSTANDING_KEY'
        secureValue: contentUnderstandingKey
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e
      
      echo "Setting up Content Understanding resources..."
      
      # Create analyzer definition file using content from environment variable
      echo "Creating analyzer definition file..."
      echo $ANALYZER_CONTENT > analyzer.json
      
      # Use the endpoint and key provided by parameters
      ENDPOINT=$CONTENT_UNDERSTANDING_ENDPOINT
      API_KEY=$CONTENT_UNDERSTANDING_KEY
      API_VERSION="2024-12-01-preview"
      
      # Check if analyzer already exists
      echo "Checking if analyzer $ANALYZER_NAME already exists..."
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        "${ENDPOINT}contentunderstanding/analyzers/${ANALYZER_NAME}?api-version=${API_VERSION}" \
        -H "Ocp-Apim-Subscription-Key: $API_KEY")
      
      if [ "$HTTP_CODE" == "200" ]; then
        echo "Analyzer $ANALYZER_NAME already exists. Skipping creation."
      else
        echo "Analyzer not found. Creating analyzer $ANALYZER_NAME..."
        # Deploy the analyzer using curl
        curl -v -X PUT \
          "${ENDPOINT}contentunderstanding/analyzers/${ANALYZER_NAME}?api-version=${API_VERSION}" \
          -H "Content-Type: application/json" \
          -H "Ocp-Apim-Subscription-Key: $API_KEY" \
          -d @analyzer.json
        
        echo "Content Understanding analyzer created successfully."
      fi
    '''
  }
}

output analyzerName string = analyzerName
