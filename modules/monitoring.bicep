// ---------------------------------------------------------------------------
// Central Monitoring — Log Analytics Workspace + Application Insights
//
// All brands-advisory services send telemetry to this shared instance.
// Applications must set their cloud_RoleName (via TelemetryInitializer or
// APPLICATIONINSIGHTS_ROLE_NAME) to distinguish per-service data in the portal.
//
// Application Insights is workspace-based (not classic).
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string

@description('Name of the Log Analytics Workspace.')
param logAnalyticsName string

@description('Name of the Application Insights instance.')
param appInsightsName string

@description('Data retention in days (31–730).')
param retentionInDays int = 90

@description('Resource tags.')
param tags object = {}

// ---------------------------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Application Insights (workspace-based)
// ---------------------------------------------------------------------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: retentionInDays
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Resource ID of the Log Analytics Workspace.')
output logAnalyticsId string = logAnalytics.id

@description('Name of the Log Analytics Workspace.')
output logAnalyticsName string = logAnalytics.name

@description('Name of the Application Insights instance.')
output appInsightsName string = appInsights.name

@description('Instrumentation Key of the Application Insights instance.')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('Connection String of the Application Insights instance.')
output connectionString string = appInsights.properties.ConnectionString
