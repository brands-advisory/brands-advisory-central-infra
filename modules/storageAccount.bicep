// ---------------------------------------------------------------------------
// Azure Storage Account — Blob storage for images and static web assets
//
// Creates a StorageV2 account with two public blob containers:
//   - 'images'  : served directly from the public blob endpoint;
//                 blobs not accessed for 120 days are automatically deleted.
//   - 'web'     : static web assets; no lifecycle policy.
// Write access is controlled via RBAC (see storage-rbac.bicep).
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string

@description('Globally unique name for the Storage Account (3-24 lowercase alphanumeric).')
param storageAccountName string

@description('Resource tags.')
param tags object = {}

// ---------------------------------------------------------------------------
// Storage Account
// ---------------------------------------------------------------------------
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    // CORS: allow direct browser-to-blob uploads (used by the /api/images/sas endpoint).
    // PUT + OPTIONS are required for single-part uploads.
    // The wildcard origin is intentional — blob URLs must be publicly accessible,
    // and restricting by origin here would break uploads from custom domains.
    cors: {
      corsRules: [
        {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'PUT', 'OPTIONS']
          allowedHeaders: ['*']
          exposedHeaders: ['ETag']
          maxAgeInSeconds: 3600
        }
      ]
    }
    lastAccessTimeTrackingPolicy: {
      enable: true
      name: 'AccessTimeTracking'
      trackingGranularityInDays: 1
      blobType: ['blockBlob']
    }
  }
}

// ---------------------------------------------------------------------------
// Containers
// ---------------------------------------------------------------------------
resource imagesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'images'
  parent: blobService
  properties: {
    publicAccess: 'Blob'
  }
}

resource webContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'web'
  parent: blobService
  properties: {
    publicAccess: 'Blob'
  }
}

// ---------------------------------------------------------------------------
// Lifecycle Management
//
// Images not accessed for 120 days are automatically deleted.
// This removes orphaned images when content is deleted or replaced.
// Last access time is tracked per blob with 1-day granularity.
// ---------------------------------------------------------------------------
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    policy: {
      rules: [
        {
          name: 'delete-unreferenced-images'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['images/']
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterLastAccessTimeGreaterThan: 120
                }
              }
            }
          }
        }
      ]
    }
  }
  dependsOn: [blobService]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Name of the deployed Storage Account.')
output storageAccountName string = storageAccount.name

@description('Primary blob service endpoint URI.')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
