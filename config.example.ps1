# Copy this file to config.ps1 and fill in your values.
# NEVER commit config.ps1 to source control.

$config = @{
    # Azure
    SubscriptionId       = "__SUBSCRIPTION_ID__"
    ResourceGroup        = "__RESOURCE_GROUP__"
    Location             = "__LOCATION__"             # e.g. westeurope

    # Entra ID
    TenantId             = "__TENANT_ID__"

    # GitHub Actions OIDC
    # Service principal used by GitHub Actions to authenticate to Azure.
    # Created via Set-FederatedCredential.ps1 in cloud-admin-toolkit.
    AzureClientId        = "__AZURE_CLIENT_ID__"

    # App Service Plan
    PlanName             = "plan-brands-advisory"

    # Key Vault
    KeyVaultName         = "__KEY_VAULT_NAME__"

    # Storage
    StorageAccountName   = "__STORAGE_ACCOUNT_NAME__"

    # Monitoring
    AppInsightsName      = "__APP_INSIGHTS_NAME__"
    LogAnalyticsName     = "__LOG_ANALYTICS_NAME__"

    # Cosmos DB
    CosmosAccountName    = "__COSMOS_ACCOUNT_NAME__"
    CosmosDatabaseName   = "__COSMOS_DATABASE_NAME__"

    # Monitoring Alerts
    AlertEmailAddress    = "__ALERT_EMAIL_ADDRESS__"
}
