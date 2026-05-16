# brands-advisory-central-infra

Infrastructure as Code for central shared Azure resources used across all brands-advisory projects.
All resources are deployed via Bicep using `az deployment group create` and parameterised through
`config.ps1` (local, never committed) and GitHub Actions secrets (CI/CD).

---

## Table of Contents

- [Deployed Resources](#deployed-resources)
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
| Default name        | configurable via `CosmosAccountName` |
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
| `KeyVaultName`       | Name of the shared Key Vault (for future use)                      |
| `StorageAccountName` | Name of the shared Storage Account (for future use)                |
| `AppInsightsName`    | Name of the Application Insights instance (for future use)         |
| `LogAnalyticsName`   | Name of the Log Analytics Workspace (for future use)               |

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

# 2. Deploy to Azure
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
