targetScope = 'subscription'

@description('Location for the central resource group.')
param location string = deployment().location

@description('Name of the central resource group.')
param centralResourceGroupName string = 'rg-brands-advisory-central'

@description('Tags applied to the central resource group.')
param tags object = {
  environment: 'production'
  managedBy: 'bicep'
  repository: 'brands-advisory-central-infra'
}

module centralResourceGroup './modules/resourceGroup.bicep' = {
  name: 'central-resource-group'
  params: {
    location: location
    name: centralResourceGroupName
    tags: tags
  }
}

output resourceGroupId string = centralResourceGroup.outputs.resourceGroupId
output resourceGroupName string = centralResourceGroup.outputs.name
