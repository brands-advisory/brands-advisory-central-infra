# brands-advisory-central-infra

Infrastructure as code for centrally managed Azure resources using Bicep modules.

## Repository structure

```text
modules/        Reusable Bicep modules
environments/   Environment-specific parameter files
.github/
  workflows/    GitHub Actions deployment pipeline (OIDC-based)
main.bicep      Entry point for the central resource group deployment
main.bicepparam Default parameter file
```

## What gets deployed

The current entry point deploys the central resource group `rg-brands-advisory-central` at subscription scope.
`main.bicepparam` provides generic defaults for local validation, while
`environments/production.bicepparam` contains the production deployment values used by the workflow.

## Prerequisites

- Azure CLI with Bicep support
- An Azure subscription where the deployment identity can create resource groups
- GitHub repository variables for the deployment workflow:
  - `AZURE_CLIENT_ID`
  - `AZURE_DEPLOYMENT_LOCATION`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

## Local validation

```bash
bicep lint main.bicep
bicep build main.bicep
bicep build-params main.bicepparam
bicep build-params environments/production.bicepparam
```

## Local deployment

```bash
az deployment sub create \
  --name central-infra-local \
  --location westeurope \
  --template-file main.bicep \
  --parameters @main.bicepparam
```

## GitHub Actions deployment

The workflow in `.github/workflows/deploy-central-infrastructure.yml` uses OpenID Connect (OIDC) via `azure/login` and does not require a client secret.
