targetScope = 'resourceGroup'

/*
  Log Analytics workspace, data collection endpoint and action group.

  The workspace is the single pane the whole demonstration is built on: agent
  telemetry from the estate virtual machines and injected synthetic estate
  history land in the same workspace, so a single KQL query can join real
  machine signals to the wider simulated estate.

  A daily ingestion cap is set deliberately. An unattended demonstration
  environment should not be able to produce a surprising bill, and hitting the
  cap degrades the demo rather than the budget.
*/

param baseName string
param location string
param tags object

@description('Workspace retention in days. 30 is the minimum billable value.')
param logRetentionInDays int = 30

@description('Daily ingestion cap in GB. A guardrail for an unattended demo environment.')
param dailyQuotaGb int = 5

@description('Optional email recipients for alert notifications. Empty means notify nobody.')
param alertEmailAddresses array = []

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${baseName}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionInDays
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

/*
  The data collection endpoint is the ingestion target for the Logs Ingestion
  API, which is how synthetic estate history is written into custom tables. The
  agents on the virtual machines do not strictly require it, but sharing one
  endpoint keeps the resource list short and legible in the portal.
*/
resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: 'dce-${baseName}'
  location: location
  tags: tags
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// The action group exists even with no recipients so every alert rule has a
// valid target. With no addresses supplied it notifies nobody, which is the
// right default for a throwaway demonstration subscription.
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${baseName}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: take(replace(baseName, '-', ''), 12)
    enabled: true
    emailReceivers: [
      for (email, index) in alertEmailAddresses: {
        name: 'email${index}'
        emailAddress: email
        useCommonAlertSchema: true
      }
    ]
  }
}

output workspaceId string = logAnalytics.id
output workspaceName string = logAnalytics.name
output workspaceCustomerId string = logAnalytics.properties.customerId
output dataCollectionEndpointId string = dataCollectionEndpoint.id
output dataCollectionEndpointLogsIngestion string = dataCollectionEndpoint.properties.logsIngestion.endpoint
output actionGroupId string = actionGroup.id
