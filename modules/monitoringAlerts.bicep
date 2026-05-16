// ---------------------------------------------------------------------------
// Monitoring Alert Rules
//
// Metric alerts for all central infrastructure resources.
// All resources in this module must be deployed to 'global'.
// Notifications are sent to the configured email via the Action Group.
// ---------------------------------------------------------------------------

@description('Email address that receives alert notifications.')
param alertEmailAddress string

@description('Cosmos DB account name.')
param cosmosAccountName string

@description('App Service Plan name.')
param appServicePlanName string

@description('Application Insights name.')
param appInsightsName string

@description('Key Vault name.')
param keyVaultName string

@description('Storage Account name.')
param storageAccountName string

@description('Resource tags.')
param tags object = {}

// ---------------------------------------------------------------------------
// Action Group — primary notifications
// ---------------------------------------------------------------------------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-brands-advisory-central'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'ba-central'
    enabled: true
    emailReceivers: [
      {
        name: 'Primary Contact'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Application Insights Smart Detection — wire up email notification
//
// Azure auto-creates this action group (empty) when Application Insights is
// provisioned. Deploying a resource with the same name updates it in-place.
// Smart Detection does not support the common alert schema, so it is disabled.
// ---------------------------------------------------------------------------
resource smartDetectionActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'Application Insights Smart Detection'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'SmartDetect'
    enabled: true
    emailReceivers: [
      {
        name: 'Primary Contact'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: false
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Cosmos DB — RU Consumption > 80 %
// Fires before the Free Tier hard limit (1 000 RU/s) causes throttling.
// ---------------------------------------------------------------------------
resource cosmosRuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-cosmos-ru-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'Cosmos DB RU consumption above 80 % — throttling risk on Free Tier.'
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosAccountName)]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighRUConsumption'
          metricName: 'NormalizedRUConsumption'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// ---------------------------------------------------------------------------
// Cosmos DB — Storage > 20 GB
// Fires 5 GB before the 25 GB Free Tier storage limit.
// ---------------------------------------------------------------------------
resource cosmosStorageAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-cosmos-storage-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'Cosmos DB storage above 20 GB — approaching the 25 GB Free Tier limit.'
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosAccountName)]
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighStorage'
          metricName: 'DataUsage'
          operator: 'GreaterThan'
          threshold: 21474836480  // 20 GB in bytes
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// ---------------------------------------------------------------------------
// Cosmos DB — Throttled Requests (HTTP 429)
// Any throttling means the RU budget is already exhausted.
// ---------------------------------------------------------------------------
resource cosmosThrottleAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-cosmos-throttled'
  location: 'global'
  tags: tags
  properties: {
    description: 'Cosmos DB requests are being throttled (HTTP 429) — RU limit exceeded.'
    severity: 1
    enabled: true
    scopes: [resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosAccountName)]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ThrottledRequests'
          metricName: 'TotalRequests'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'StatusCode'
              operator: 'Include'
              values: ['429']
            }
          ]
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// ---------------------------------------------------------------------------
// App Service Plan — CPU > 80 %
// ---------------------------------------------------------------------------
resource planCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-plan-cpu-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'App Service Plan CPU above 80 % for 5 minutes — consider scaling up.'
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.Web/serverfarms', appServicePlanName)]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCpu'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// ---------------------------------------------------------------------------
// App Service Plan — Memory > 85 %
// ---------------------------------------------------------------------------
resource planMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-plan-memory-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'App Service Plan memory above 85 % — risk of OOM restarts.'
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.Web/serverfarms', appServicePlanName)]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemory'
          metricName: 'MemoryPercentage'
          operator: 'GreaterThan'
          threshold: 85
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// ---------------------------------------------------------------------------
// Application Insights — Failed Requests
// ---------------------------------------------------------------------------
resource failedRequestsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-appinsights-failed-requests'
  location: 'global'
  tags: tags
  properties: {
    description: 'More than 10 failed HTTP requests in 5 minutes.'
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.Insights/components', appInsightsName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighFailedRequests'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// ---------------------------------------------------------------------------
// Key Vault — Authorization Failures (HTTP 403)
// ---------------------------------------------------------------------------
resource kvAuthAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-kv-auth-failures'
  location: 'global'
  tags: tags
  properties: {
    description: 'More than 5 Key Vault authorization failures (HTTP 403) in 5 minutes — possible unauthorized access attempt.'
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.KeyVault/vaults', keyVaultName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'AuthFailures'
          metricName: 'ServiceApiResult'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'StatusCode'
              operator: 'Include'
              values: ['403']
            }
          ]
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// ---------------------------------------------------------------------------
// Storage Account — Availability < 99 %
// ---------------------------------------------------------------------------
resource storageAvailabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-storage-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'Storage Account availability below 99 %.'
    severity: 1
    enabled: true
    scopes: [resourceId('Microsoft.Storage/storageAccounts', storageAccountName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'LowAvailability'
          metricName: 'Availability'
          operator: 'LessThan'
          threshold: 99
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}
