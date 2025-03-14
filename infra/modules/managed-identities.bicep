@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Resource token for unique resource naming')
param resourceToken string

@description('Abbreviations to use for resource naming')
param abbrs object

// Create managed identities for the container apps
module chunkVideoContentIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'chunkVideoContentidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}chunkVideoContent-${resourceToken}'
    location: location
  }
}

module indexFileApiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'indexFileApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}indexFileApi-${resourceToken}'
    location: location
  }
}

module summarizeVideoContentIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'summarizeVideoContentidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}summarizeVideoContent-${resourceToken}'
    location: location
  }
}

output chunkVideoContentIdentityResourceId string = chunkVideoContentIdentity.outputs.resourceId
output chunkVideoContentIdentityClientId string = chunkVideoContentIdentity.outputs.clientId
output chunkVideoContentIdentityPrincipalId string = chunkVideoContentIdentity.outputs.principalId

output indexFileApiIdentityResourceId string = indexFileApiIdentity.outputs.resourceId
output indexFileApiIdentityClientId string = indexFileApiIdentity.outputs.clientId
output indexFileApiIdentityPrincipalId string = indexFileApiIdentity.outputs.principalId

output summarizeVideoContentIdentityResourceId string = summarizeVideoContentIdentity.outputs.resourceId
output summarizeVideoContentIdentityClientId string = summarizeVideoContentIdentity.outputs.clientId
output summarizeVideoContentIdentityPrincipalId string = summarizeVideoContentIdentity.outputs.principalId

output managedIdentityPrincipalIds array = [
  chunkVideoContentIdentity.outputs.principalId
  indexFileApiIdentity.outputs.principalId
  summarizeVideoContentIdentity.outputs.principalId
]