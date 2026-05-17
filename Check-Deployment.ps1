<#
.SYNOPSIS
    Shows what would change if the Bicep template were deployed now.

.DESCRIPTION
    Runs 'az deployment group what-if' against the current infra/main.bicep
    using values from config.ps1. No changes are made to Azure.

.EXAMPLE
    .\Check-Deployment.ps1

.NOTES
    Requires: Azure CLI (az), logged in via 'az login'.
    Run '.\setup.ps1 -Bicep' first to generate infra/main.local.bicepparam.
#>

$configPath = Join-Path $PSScriptRoot 'config.ps1'
if (-not (Test-Path $configPath)) {
    Write-Error "config.ps1 not found. Copy config.example.ps1 to config.ps1 and fill in your values."
    exit 1
}
. $configPath

$bicepParam = Join-Path $PSScriptRoot 'infra/main.local.bicepparam'
if (-not (Test-Path $bicepParam)) {
    Write-Error "infra/main.local.bicepparam not found. Run '.\setup.ps1 -Bicep' first."
    exit 1
}

Write-Host "Running What-If against '$($config.ResourceGroup)'..." -ForegroundColor Cyan

az deployment group what-if `
    --resource-group $config.ResourceGroup `
    --template-file (Join-Path $PSScriptRoot 'infra/main.bicep') `
    --parameters (Join-Path $PSScriptRoot 'infra/main.local.bicepparam')
