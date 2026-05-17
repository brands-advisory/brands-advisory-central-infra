# brands-advisory-central-infra

Infrastructure as Code for central shared Azure resources used across all brands-advisory projects.
All resources are deployed via Bicep using `az deployment group create` and parameterised through
`config.ps1` (local, never committed) and GitHub Actions secrets (CI/CD).

---

## Table of Contents

- [Deployed Resources](#deployed-resources)
  - [Monitoring Alerts](#monitoring-alerts)
- [Repository Structure](#repository-structure)
- [Initial Setup (once)](#initial-setup-once)
  - [1. Create Resource Group](#1-create-resource-group)
  - [2. Create Deployment Service Principal](#2-create-deployment-service-principal)
  - [3. Add OIDC Federated Credential](#3-add-oidc-federated-credential)
- [Setup](#setup)
  - [Prerequisites](#prerequisites)
  - [Local Configuration](#local-configuration)
  - [Applying Configuration](#applying-configuration)
- [Deployment](#deployment)
  - [Local](#local)
  - [GitHub Actions](#github-actions)
- [Post-Deployment Checklist](#post-deployment-checklist)
- [GitHub Secrets](#github-secrets)
- [Tags](#tags)

---

## Deployed Resources

### App Service Plan — `Microsoft.Web/serverfarms`

| Property        | Value                  |
|-----------------|------------------------|
| Default name    | `plan-brands-advisory` |
| SKU             | P1v4 (PremiumV4)       |
| OS              | Linux                  |
| Location        | configurable           |
| Module          | `modules/appServicePlan.bicep` |

Shared Linux App Service Plan used as the hosting target for all brands-advisory web applications.
Individual apps (e.g. brands-advisory-cms) create their App Service resources and reference this
plan by its resource ID output (`appServicePlanId`).

### Key Vault — `Microsoft.KeyVault/vaults`

| Property               | Value                        |
|------------------------|------------------------------|
| Default name           | configurable via `KeyVaultName` |
| SKU                    | Standard                     |
| Authorization model    | RBAC (not Access Policies)   |
| Soft delete            | enabled, 90-day retention    |
| Location               | configurable                 |
| Module                 | `modules/keyVault.bicep`     |

Shared Key Vault for storing secrets and certificates used across all brands-advisory services
(e.g. the Entra ID authentication certificate for brands-advisory-cms).
Role assignments are managed separately and not part of this deployment.
The Entra ID certificate must be uploaded manually after the Key Vault is created.

**Outputs:** `keyVaultName`, `keyVaultUri`

### Storage Account — `Microsoft.Storage/storageAccounts`

| Property            | Value                              |
|---------------------|------------------------------------|
| Default name        | configurable via `StorageAccountName` |
| SKU                 | Standard_LRS                       |
| Kind                | StorageV2                          |
| Public blob access  | enabled                            |
| Minimum TLS         | TLS 1.2                            |
| Module              | `modules/storageAccount.bicep`     |

Shared Storage Account for blob content used across all brands-advisory services.

**Containers:**

| Container | Public access | Lifecycle                                      |
|-----------|---------------|------------------------------------------------|
| `images`  | Blob          | Blobs not accessed for 120 days are deleted    |
| `web`     | Blob          | None                                           |

CORS is configured to allow `GET`, `PUT`, and `OPTIONS` from all origins (required for direct browser-to-blob uploads via SAS token). Last-access-time tracking is enabled with 1-day granularity for the lifecycle policy.
Write access is controlled via RBAC and not part of this deployment.

**Outputs:** `storageAccountName`, `blobEndpoint`

### Monitoring — Log Analytics Workspace + Application Insights

#### Log Analytics Workspace — `Microsoft.OperationalInsights/workspaces`

| Property        | Value                              |
|-----------------|------------------------------------|
| Default name    | configurable via `LogAnalyticsName` |
| SKU             | PerGB2018                          |
| Retention       | 90 days (configurable)             |
| Module          | `modules/monitoring.bicep`         |

#### Application Insights — `Microsoft.Insights/components`

| Property        | Value                              |
|-----------------|------------------------------------|
| Default name    | configurable via `AppInsightsName` |
| Type            | Workspace-based (not classic)      |
| Kind            | web                                |
| Retention       | 90 days (configurable)             |
| Module          | `modules/monitoring.bicep`         |

Shared monitoring instance for all brands-advisory services. Each application must set
`cloud_RoleName` (via `APPLICATIONINSIGHTS_ROLE_NAME` environment variable or a
`TelemetryInitializer`) to distinguish per-service data in the portal.

**Outputs:** `appInsightsName`, `appInsightsConnectionString`

### Cosmos DB — `Microsoft.DocumentDB/databaseAccounts` (NoSQL API)

| Property            | Value                               |
|---------------------|-------------------------------------|
| Account name        | configurable via `CosmosAccountName` |
| Database name       | configurable via `CosmosDatabaseName` |
| API                 | NoSQL (GlobalDocumentDB)            |
| Free Tier           | enabled (one per subscription)      |
| Consistency         | Session                             |
| Throughput          | Free Tier (1000 RU/s, 25 GB)        |
| Containers          | none — created by apps at startup   |
| Module              | `modules/cosmosDb.bicep`            |

Deploys a Cosmos DB account and a database. No containers are provisioned here —
containers are created by the individual applications at startup.
Free Tier covers the first 1000 RU/s and 25 GB — disable it (`enableFreeTier: false`) if
another Free Tier account already exists in the subscription.
Access is controlled via RBAC and not part of this deployment.

**Outputs:** `cosmosAccountName`, `cosmosEndpoint`

### Monitoring Alerts — `Microsoft.Insights/metricAlerts` + `Microsoft.Insights/actionGroups`

| Property    | Value                              |
|-------------|------------------------------------|
| Module      | `modules/monitoringAlerts.bicep`   |
| Location    | global (required for metric alerts)|
| Notification| email via Action Group             |

One Action Group (`ag-brands-advisory-central`) routes all alerts to the configured email (`ALERT_EMAIL`).

| Alert rule                            | Resource         | Condition                       | Severity |
|---------------------------------------|------------------|---------------------------------|----------|
| `alert-cosmos-ru-high`                | Cosmos DB        | RU consumption > 80 %           | 2        |
| `alert-cosmos-storage-high`           | Cosmos DB        | Storage > 20 GB (limit: 25 GB)  | 2        |
| `alert-cosmos-throttled`              | Cosmos DB        | Throttled requests (429) > 0    | 1        |
| `alert-plan-cpu-high`                 | App Service Plan | CPU > 80 % for 5 min            | 2        |
| `alert-plan-memory-high`              | App Service Plan | Memory > 85 % for 5 min         | 2        |
| `alert-appinsights-failed-requests`   | App Insights     | Failed requests > 10 in 5 min   | 2        |
| `alert-kv-auth-failures`              | Key Vault        | HTTP 403 responses > 5 in 5 min | 2        |
| `alert-storage-availability`          | Storage Account  | Availability < 99 %             | 1        |

Severity scale: 0 = Critical, 1 = Error, 2 = Warning, 3 = Informational, 4 = Verbose.

**Tags applied to all resources:**

| Key          | Value             |
|--------------|-------------------|
| environment  | prod              |
| tier         | central           |
| project      | brands-advisory   |
| managed-by   | bicep             |

---

## Repository Structure

```
brands-advisory-central-infra/
├── infra/
│   ├── main.bicep               # Deployment entry point
│   └── main.local.bicepparam    # Generated locally by setup.ps1 (not committed)
├── modules/
│   └── appServicePlan.bicep     # Linux PremiumV4 App Service Plan
├── config.example.ps1           # Configuration template — copy to config.ps1
├── setup.ps1                    # Distributes config values to GitHub Secrets / bicepparam
├── Check-Deployment.ps1         # Runs what-if against Azure to preview changes
├── .gitignore
└── README.md
```

---

## Initial Setup (once)

Before GitHub Actions can deploy infrastructure, a one-time manual setup is required
to bootstrap the deployment identity and permissions.

### 1. Create Resource Group

```bash
az group create \
  --name <resource-group-name> \
  --location <location>
```

### 2. Create Deployment Service Principal

Use `Create-ServicePrincipalForDeployment.ps1` from [cloud-admin-toolkit](https://github.com/brands-advisory/cloud-admin-toolkit):

```powershell
.\Create-ServicePrincipalForDeployment.ps1 -ConfigName <project-name>
```

### 3. Add OIDC Federated Credential

Use `Add-FederatedCredentialForGitHub.ps1` from [cloud-admin-toolkit](https://github.com/brands-advisory/cloud-admin-toolkit):

```powershell
.\Add-FederatedCredentialForGitHub.ps1 -ConfigName <project-name>
```

After this step no client secret is stored anywhere. OIDC handles authentication via GitHub's identity provider.

---

## Setup

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) — for deployment and Key Vault
- [GitHub CLI](https://cli.github.com/) — for setting GitHub Secrets (`winget install GitHub.cli`)
- Contributor role on the target resource group

### Local Configuration

Copy `config.example.ps1` to `config.ps1` and fill in all values.
`config.ps1` is excluded from source control via `.gitignore` and must **never** be committed.

```powershell
Copy-Item config.example.ps1 config.ps1
# Edit config.ps1 with your actual values
```

**Configuration values:**

| Key                  | Description                                                        |
|----------------------|--------------------------------------------------------------------|
| `SubscriptionId`     | Azure Subscription ID                                              |
| `ResourceGroup`      | Target resource group name                                         |
| `Location`           | Azure region, e.g. `germanywestcentral`                            |
| `TenantId`           | Entra ID Tenant ID                                                 |
| `AzureClientId`      | Client ID of the GitHub Actions OIDC service principal             |
| `PlanName`           | Name of the App Service Plan (default: `plan-brands-advisory`)     |
| `KeyVaultName`       | Name of the shared Key Vault                                       |
| `StorageAccountName` | Name of the shared Storage Account                                 |
| `AppInsightsName`    | Name of the Application Insights instance                          |
| `LogAnalyticsName`   | Name of the Log Analytics Workspace                                |
| `CosmosAccountName`  | Globally unique name of the Cosmos DB account                      |
| `CosmosDatabaseName` | Name of the Cosmos DB database                                     |
| `AlertEmailAddress`  | Email address for monitoring alert notifications                   |

### Applying Configuration

`setup.ps1` reads `config.ps1` and distributes values to the configured targets:

```powershell
.\setup.ps1 -All         # GitHub Secrets + generate bicepparam
.\setup.ps1 -GitHub      # GitHub Secrets only
.\setup.ps1 -Bicep       # Generate infra/main.local.bicepparam only
```

---

## Deployment

### Local

```powershell
# 1. Generate infra/main.local.bicepparam from config.ps1
.\setup.ps1 -Bicep

# 2. Preview changes (What-If) — shows what would be created/modified without deploying
.\Check-Deployment.ps1

# 3. Deploy to Azure
az deployment group create `
  --resource-group <ResourceGroup> `
  --template-file infra/main.bicep `
  --parameters infra/main.local.bicepparam
```

### GitHub Actions

GitHub Actions authenticates to Azure via OIDC (no stored credentials).
Run `.\setup.ps1 -GitHub` once to push all required secrets to the repository,
then trigger the workflow manually or on push.

---

## Post-Deployment Checklist

The Bicep deployment provisions all resources but does not configure RBAC or upload secrets.
Complete the following steps manually after the **first deployment** to a new environment.

### 1. Key Vault — RBAC Role Assignments

Grant identities the roles they need. Use the Key Vault URI from the deployment output (`keyVaultUri`).

```powershell
# Example: grant a developer read access to secrets
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee <object-id-or-upn> \
  --scope $(az keyvault show --name <keyVaultName> --query id -o tsv)
```

Common roles: `Key Vault Secrets User` (read), `Key Vault Secrets Officer` (write), `Key Vault Certificates Officer` (certificates).

### 2. Key Vault — Upload Entra ID Certificate

Upload the certificate used by consumer services (e.g. brands-advisory-cms) for Entra ID authentication.

```powershell
az keyvault certificate import \
  --vault-name <keyVaultName> \
  --name <certificate-name> \
  --file <path-to-pfx> \
  --password <pfx-password>
```

### 3. Storage Account — RBAC Role Assignments

Grant App Service managed identities write access to blob containers.

```powershell
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <managed-identity-object-id> \
  --scope $(az storage account show --name <storageAccountName> --query id -o tsv)
```

### 4. Cosmos DB — RBAC Role Assignments

Grant App Service managed identities data-plane access.

```powershell
az cosmosdb sql role assignment create \
  --account-name <cosmosAccountName> \
  --resource-group <ResourceGroup> \
  --role-definition-name "Cosmos DB Built-in Data Contributor" \
  --principal-id <managed-identity-object-id> \
  --scope "/"
```

### 5. Retrieve and Distribute Outputs

Retrieve deployment outputs to wire up consumer projects:

```powershell
az deployment group show \
  --resource-group <ResourceGroup> \
  --name main \
  --query properties.outputs
```

| Output                        | Used by                                          |
|-------------------------------|--------------------------------------------------|
| `appServicePlanId`            | App Service resources in consumer projects       |
| `keyVaultName`                | Services that read secrets or certificates       |
| `keyVaultUri`                 | RBAC scope and SDK configuration                 |
| `storageAccountName`          | Services that access blob storage                |
| `blobEndpoint`                | Frontend image and asset URLs                    |
| `appInsightsConnectionString` | `APPLICATIONINSIGHTS_CONNECTION_STRING` env var  |
| `cosmosAccountName`           | Cosmos DB RBAC scope                             |
| `cosmosEndpoint`              | SDK endpoint configuration                       |

---

## GitHub Secrets

The following secrets are set by `setup.ps1 -GitHub` and consumed by GitHub Actions workflows:

| Secret                  | Source config key      | Description                              |
|-------------------------|------------------------|------------------------------------------|
| `AZURE_CLIENT_ID`       | `AzureClientId`        | OIDC service principal client ID         |
| `AZURE_SUBSCRIPTION_ID` | `SubscriptionId`       | Target subscription                      |
| `AZURE_RESOURCE_GROUP`  | `ResourceGroup`        | Target resource group                    |
| `AZURE_TENANT_ID`       | `TenantId`             | Entra ID tenant                          |
| `AZURE_LOCATION`        | `Location`             | Azure region                             |
| `PLAN_NAME`             | `PlanName`             | App Service Plan name                    |
| `KEY_VAULT_NAME`        | `KeyVaultName`         | Shared Key Vault name                    |
| `STORAGE_ACCOUNT_NAME`  | `StorageAccountName`   | Shared Storage Account name              |
| `APP_INSIGHTS_NAME`     | `AppInsightsName`      | Application Insights instance name       |
| `LOG_ANALYTICS_NAME`    | `LogAnalyticsName`     | Log Analytics Workspace name             |
| `COSMOS_ACCOUNT_NAME`   | `CosmosAccountName`    | Cosmos DB account name                   |
| `COSMOS_DATABASE_NAME`  | `CosmosDatabaseName`   | Cosmos DB database name                  |
| `ALERT_EMAIL`           | `AlertEmailAddress`    | Recipient for monitoring alert emails    |

---

## Tags

All resources deployed by this repository carry the following tags:

```bicep
{
  environment: 'prod'
  tier:        'central'
  project:     'brands-advisory-central-infra'
  'managed-by': 'bicep'
}
```
