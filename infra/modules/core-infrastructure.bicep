@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Principal IDs for managed identities that need access to the container registry')
param managedIdentityPrincipalIds array = []

@description('ID of the user or app to assign access policies for Key Vault')
param principalId string

var abbrs = loadJsonContent('../abbreviations.json')
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
    roleAssignments: [for principalId in managedIdentityPrincipalIds: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    }]
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

// Create access policies for managed identities
var managedIdentityPolicies = [for id in managedIdentityPrincipalIds: {
  objectId: id
  permissions: {
    secrets: [ 'get', 'list' ]
  }
}]

// Create access policies for all identities
var allAccessPolicies = concat([
  {
    objectId: principalId
    permissions: {
      secrets: [ 'get', 'list' ]
    }
  }
], managedIdentityPolicies)

// Deploy Key Vault
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: 'keyvault'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    enableRbacAuthorization: false
    accessPolicies: allAccessPolicies
    secrets: []
  }
}

output logAnalyticsWorkspaceResourceId string = monitoring.outputs.logAnalyticsWorkspaceResourceId
output applicationInsightsResourceId string = monitoring.outputs.applicationInsightsResourceId
output applicationInsightsConnectionString string = monitoring.outputs.applicationInsightsConnectionString
output containerRegistryResourceId string = containerRegistry.outputs.resourceId
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output containerAppsEnvironmentResourceId string = containerAppsEnvironment.outputs.resourceId
output keyVaultResourceId string = keyVault.outputs.resourceId
output keyVaultUri string = keyVault.outputs.uri
output keyVaultName string = keyVault.outputs.name
