/// Deploys a Linux App Service Plan (PremiumV4 P1v4) for hosting web apps.
@description('Name of the App Service Plan.')
param planName string

@description('Azure region for the resource.')
param location string

@description('Resource tags.')
param tags object = {
  environment: 'prod'
  tier: 'central'
  project: 'brands-advisory-central-infra'
  'managed-by': 'bicep'
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'P1v4'
    tier: 'PremiumV4'
    size: 'P1v4'
    family: 'Pv4'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
    asyncScalingEnabled: false
  }
}

@description('Resource ID of the deployed App Service Plan.')
output planId string = appServicePlan.id

@description('Name of the deployed App Service Plan.')
output planName string = appServicePlan.name
