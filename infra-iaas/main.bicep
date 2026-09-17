targetScope = 'subscription'

/*
  Unified Operational Intelligence — infrastructure-as-a-service demonstration.

  This template builds a simulated insurance estate out of real Azure virtual
  machines and instruments it entirely with native Azure Monitor services. The
  demonstration surface is the Azure portal itself: VM Insights, Log Analytics,
  Azure Monitor alerts, a workbook and a shared dashboard. There is no custom
  web application and no container.

  Everything the estate represents is synthetic. Machines are tagged as such,
  and any injected estate history carries an explicit synthetic marker, so no
  part of the demonstration can be mistaken for customer data.
*/

@description('Short name used to derive every resource name.')
@minLength(2)
@maxLength(12)
param baseName string = 'uoi'

@description('Azure region for the estate.')
param location string = 'eastus2'

@description('Resource group to create or update.')
param resourceGroupName string = 'rg-${baseName}-iaas'

@description('SSH public key for the estate administrator account. A public key is not a secret.')
param adminPublicKey string

@description('Optional email recipients for alert notifications. Empty means notify nobody.')
param alertEmailAddresses array = []

@description('Daily Log Analytics ingestion cap in GB, as a cost guardrail.')
param dailyQuotaGb int = 5

var tags = {
  solution: 'unified-operational-intelligence'
  environment: 'demo'
  dataClassification: 'Synthetic Demo Data'
  isSynthetic: 'true'
  deployedBy: 'bicep'
}

resource estateResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
    dailyQuotaGb: dailyQuotaGb
    alertEmailAddresses: alertEmailAddresses
  }
}

module estate 'modules/vms.bicep' = {
  name: 'estate'
  scope: estateResourceGroup
  params: {
    location: location
    tags: tags
    webSubnetId: network.outputs.webSubnetId
    appSubnetId: network.outputs.appSubnetId
    dataSubnetId: network.outputs.dataSubnetId
    adminPublicKey: adminPublicKey
  }
}

module collection 'modules/dcr.bicep' = {
  name: 'collection'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
    workspaceId: monitoring.outputs.workspaceId
    vmNames: estate.outputs.vmNames
  }
}

module automation 'modules/automation.bicep' = {
  name: 'automation'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
  }
}

module estateHistory 'modules/custom-tables.bicep' = {
  name: 'estateHistory'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
    workspaceName: monitoring.outputs.workspaceName
    dataCollectionEndpointId: monitoring.outputs.dataCollectionEndpointId
    // The estate machines seed synthetic history; the Automation account writes
    // the remediation audit trail. Both authenticate as managed identities.
    ingestionPrincipalIds: union(estate.outputs.vmPrincipalIds, [
      automation.outputs.automationPrincipalId
    ])
  }
}

module alerting 'modules/alerts.bicep' = {
  name: 'alerting'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
    actionGroupId: monitoring.outputs.actionGroupId
    workspaceId: monitoring.outputs.workspaceId
    vmIds: estate.outputs.vmIds
  }
  dependsOn: [
    estateHistory
  ]
}

module workbook 'modules/workbook.bicep' = {
  name: 'workbook'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
    workspaceId: monitoring.outputs.workspaceId
  }
}

module dashboard 'modules/dashboard.bicep' = {
  name: 'dashboard'
  scope: estateResourceGroup
  params: {
    baseName: baseName
    location: location
    tags: tags
    vmIds: estate.outputs.vmIds
    workbookId: workbook.outputs.workbookId
  }
}

output resourceGroupName string = estateResourceGroup.name
output workspaceName string = monitoring.outputs.workspaceName
output workspaceId string = monitoring.outputs.workspaceId
output workspaceCustomerId string = monitoring.outputs.workspaceCustomerId
output dataCollectionEndpoint string = monitoring.outputs.dataCollectionEndpointLogsIngestion
output ingestionRuleImmutableId string = estateHistory.outputs.ingestionRuleImmutableId
output vmNames array = estate.outputs.vmNames
output workbookId string = workbook.outputs.workbookId
output automationAccountName string = automation.outputs.automationAccountName
output runbookName string = automation.outputs.runbookName
