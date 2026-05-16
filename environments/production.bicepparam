using '../main.bicep'

param location = 'westeurope'
param centralResourceGroupName = 'rg-brands-advisory-central'
param tags = {
  environment: 'production'
  managedBy: 'bicep'
  repository: 'brands-advisory-central-infra'
}
