using './main.bicep'

param location = 'westeurope'
param centralResourceGroupName = 'rg-brands-advisory-central'
param tags = {
  environment: 'default'
  managedBy: 'bicep'
  repository: 'brands-advisory-central-infra'
}
