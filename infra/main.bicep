/// Central infrastructure deployment for brands-advisory.
/// Deploy with: az deployment group create -g <rg> -f main.bicep -p main.local.bicepparam
targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the App Service Plan.')
param planName string

@description('Name of the Key Vault.')
param keyVaultName string

@description('Entra ID Tenant ID.')
param tenantId string

@description('Globally unique name for the Storage Account (3-24 lowercase alphanumeric).')
param storageAccountName string

@description('Name of the Application Insights instance.')
param appInsightsName string

@description('Name of the Log Analytics Workspace.')
param logAnalyticsName string

@description('Globally unique name for the Cosmos DB account.')
param cosmosAccountName string

@description('Name of the Cosmos DB database.')
param cosmosDatabaseName string

// ---------------------------------------------------------------------------
// App Service Plan
// ---------------------------------------------------------------------------
module appServicePlan '../modules/appServicePlan.bicep' = {
  name: 'appServicePlan'
  params: {
    planName: planName
    location: location
  }
}

// ---------------------------------------------------------------------------
// Key Vault
// ---------------------------------------------------------------------------
module keyVault '../modules/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: keyVaultName
    location: location
    tenantId: tenantId
  }
}

// ---------------------------------------------------------------------------
// Storage Account
// ---------------------------------------------------------------------------
module storageAccount '../modules/storageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

// ---------------------------------------------------------------------------
// Monitoring
// ---------------------------------------------------------------------------
module monitoring '../modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    location: location
  }
}

// ---------------------------------------------------------------------------
// Cosmos DB
// ---------------------------------------------------------------------------
module cosmosDb '../modules/cosmosDb.bicep' = {
  name: 'cosmosDb'
  params: {
    accountName: cosmosAccountName
    databaseName: cosmosDatabaseName
    location: location
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Resource ID of the App Service Plan.')
output appServicePlanId string = appServicePlan.outputs.planId

@description('Name of the deployed Key Vault.')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('URI of the deployed Key Vault.')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Name of the deployed Storage Account.')
output storageAccountName string = storageAccount.outputs.storageAccountName

@description('Primary blob endpoint of the deployed Storage Account.')
output blobEndpoint string = storageAccount.outputs.blobEndpoint

@description('Name of the deployed Application Insights instance.')
output appInsightsName string = monitoring.outputs.appInsightsName

@description('Application Insights Connection String.')
output appInsightsConnectionString string = monitoring.outputs.connectionString

@description('Cosmos DB account endpoint URI.')
output cosmosEndpoint string = cosmosDb.outputs.cosmosEndpoint

@description('Cosmos DB account name.')
output cosmosAccountName string = cosmosDb.outputs.cosmosAccountName
