@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Application Insights resource ID for monitoring')
param applicationInsightsResourceId string

@description('Resource ID of the Container App Environment')
param containerAppsEnvironmentResourceId string

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Storage account name')
param storageAccountName string

@description('Blob container name')
param blobContainerName string

@description('Cognitive Services account name')
param cognitiveServicesAccountName string = ''

@description('OpenAI deployment name')
param openAiDeploymentName string = ''

@description('Container Registry Login Server')
param containerRegistryLoginServer string

@description('Container Registry Name')
param containerRegistryName string

@description('Resource token for unique resource naming')
param resourceToken string

@description('Abbreviations to use for resource naming')
param abbrs object

@description('Name of the app')
param name string = 'summarizeVideoContent'

var keyVaultName = '${abbrs.keyVaultVaults}${resourceToken}-svc' // shortened summarize-video-content because of a length limit

// Create managed identities for the container apps
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'summarizeVideoContentidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}summarizeVideoContent-${resourceToken}'
    location: location
  }
}


// Deploy Key Vault without inline secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: keyVaultName
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enableRbacAuthorization: true
  }
}

// Grant AcrPull role to the identity on the container registry
module acrPullRole '../roles/acr-pull-role.bicep' = {
  name: '${name}-acr-pull-role'
  params: {
    containerRegistryName: containerRegistryName
    principalId: identity.outputs.principalId
    appName: name
  }
}

// Create secrets for summarize-video-content in a dedicated module
module summarizeVideoContentSecrets 'secrets.bicep' = {
  name: 'summarizeVideoContentSecrets'
  params: {
    keyVaultName: keyVaultName
    serviceBusNamespace: serviceBusNamespaceName
    storageAccountName: storageAccountName
    blobContainerName: blobContainerName
    cognitiveServicesAccountName: cognitiveServicesAccountName
    openAiDeploymentName: openAiDeploymentName
  }
  dependsOn: [
    keyVault
  ]
}

// Reference to the finalize-content queue
resource finalizeContentQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/finalize-content'
}

// Reference to the video-summary queue
resource videoSummaryQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' existing = {
  name: '${serviceBusNamespaceName}/video-summary'
}

// Grant read access to the finalize content queue using the module
module finalizeReceiverRole '../roles/service-bus-receiver-role.bicep' = {
  name: '${name}-finalize-receiver-role'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    queueName: 'finalize-content'
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn: [
    finalizeContentQueue
  ]
}

// Grant write access to the video summary queue using the module
module videoSummarySenderRole '../roles/service-bus-sender-role.bicep' = {
  name: '${name}-video-summary-sender-role'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    queueName: 'video-summary'
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn: [
    videoSummaryQueue
  ]
}

// Grant Storage Blob Data Contributor role to the identity
module storageBlobContributorRole '../roles/storage-blob-contributor-role.bicep' = if (!empty(storageAccountName)) {
  name: '${name}-storage-blob-contributor-role'
  params: {
    storageAccountName: storageAccountName
    containerName: blobContainerName
    principalId: identity.outputs.principalId
    appName: name
  }
}

// Grant Key Vault Secret User role to the identity
module keyVaultSecretUserRole '../roles/key-vault-secret-user-role.bicep' = {
  name: '${name}-key-vault-secret-user-role'
  params: {
    keyVaultName: keyVaultName
    principalId: identity.outputs.principalId
    appName: name
  }
  dependsOn:[
    keyVault
  ]
}

// Deploy Summarize Video Content Container App
module summarizeVideoContent '../container-app.bicep' = {
  name: 'summarizeVideoContentContainerApp'
  params: {
    name: name
    location: location
    tags: tags
    applicationInsightsResourceId: applicationInsightsResourceId
    containerAppsEnvironmentResourceId: containerAppsEnvironmentResourceId
    containerRegistryLoginServer: containerRegistryLoginServer
    identityResourceId: identity.outputs.resourceId
    identityClientId: identity.outputs.clientId
    secrets: {
      secrets: [
        {
          name: 'service-bus-namespace'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.serviceBusNamespaceSecretUri
        }
        {
          name: 'service-bus-api-key'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.serviceBusKeySecretUri
        }
        {
          name: 'service-bus-api-key-name'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.serviceBusKeyNameSecretUri
        }
        {
          name: 'finalize-content-queue'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.finalizeContentQueueNameSecretUri
        }
        {
          name: 'video-summary-queue'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.videoSummaryQueueNameSecretUri
        }
        {
          name: 'azure-openai-endpoint'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.openAiEndpointSecretUri
        }
        {
          name: 'azure-openai-key'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.openAiKeySecretUri
        }
        {
          name: 'azure-openai-api-version'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.openAiApiVersionSecretUri
        }
        {
          name: 'azure-openai-model-name'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.openAiDeploymentNameSecretUri
        }
        {
          name: 'content-understanding-endpoint'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.contentUnderstandingEndpointSecretUri
        }
        {
          name: 'content-understanding-key'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.contentUnderstandingKeySecretUri
        }
        {
          name: 'content-understanding-api-version'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.contentUnderstandingApiVersionSecretUri
        }
        {
          name: 'storage-account-name'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.storageAccountNameSecretUri
        }
        {
          name: 'storage-container-name'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.containerNameSecretUri
        }
        {
          name: 'storage-account-api-key'
          keyVaultUrl: summarizeVideoContentSecrets.outputs.storageAccountKeySecretUri
        }
      ]
    }
    envVars: [
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
    imageName: 'summarize-video-content'
  }
  dependsOn: [
    keyVaultSecretUserRole
    storageBlobContributorRole
    finalizeReceiverRole
    videoSummarySenderRole
  ]
}

output resourceId string = summarizeVideoContent.outputs.resourceId
output identityPrincipalId string = identity.outputs.principalId
output identityResourceId string = identity.outputs.resourceId
output identityClientId string = identity.outputs.clientId
