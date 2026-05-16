// ---------------------------------------------------------------------------
// Azure Cosmos DB (NoSQL API)
//
// Creates an account and a database. No containers are provisioned here —
// containers are created by the individual applications at startup.
// Free Tier is enabled — only one Free Tier account is allowed per subscription.
// Access is controlled via RBAC (see cosmosdb-rbac.bicep).
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string

@description('Globally unique name for the Cosmos DB account.')
param accountName string

@description('Name of the Cosmos DB database.')
param databaseName string

@description('Resource tags.')
param tags object = {}

// ---------------------------------------------------------------------------
// Cosmos DB Account
// ---------------------------------------------------------------------------
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    // Free Tier: first 1000 RU/s and 25 GB free — one per subscription
    enableFreeTier: true
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    // NoSQL API — no additional capabilities needed
    capabilities: []
  }
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Cosmos DB account endpoint URI.')
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint

@description('Cosmos DB account name.')
output cosmosAccountName string = cosmosAccount.name
