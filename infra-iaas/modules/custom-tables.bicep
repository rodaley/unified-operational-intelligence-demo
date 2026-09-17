targetScope = 'resourceGroup'

/*
  Custom tables and the ingestion rule for synthetic estate history.

  Six real virtual machines cannot, on their own, produce the scale an executive
  narrative needs: a multi-service estate, months of observability spend, or a
  correlated alert storm. Rather than fake that in a bespoke application, it is
  written into native Log Analytics custom tables through the Logs Ingestion
  API. Everything downstream — KQL, the workbook, the dashboard, alert rules —
  is then ordinary Azure Monitor working on ordinary tables.

  Every table carries IsSynthetic and DataClassification columns. They are not
  decorative: the workbook filters and labels on them, so no figure can appear
  on screen without its synthetic provenance attached.
*/

param baseName string
param location string
param tags object
param workspaceName string
param dataCollectionEndpointId string

@description('Object IDs permitted to publish synthetic estate history through the Logs Ingestion API.')
param ingestionPrincipalIds array = []

@description('Retention in days for the synthetic history tables.')
param retentionInDays int = 30

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workspaceName
}

resource alertTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: workspace
  name: 'UoiEstateAlert_CL'
  properties: {
    plan: 'Analytics'
    retentionInDays: retentionInDays
    schema: {
      name: 'UoiEstateAlert_CL'
      description: 'Synthetic alert records from the simulated insurance estate.'
      columns: [
        { name: 'TimeGenerated', type: 'dateTime' }
        { name: 'AlertId', type: 'string' }
        { name: 'Service', type: 'string' }
        { name: 'Component', type: 'string' }
        { name: 'Tier', type: 'string' }
        { name: 'Severity', type: 'string' }
        { name: 'Source', type: 'string' }
        { name: 'Message', type: 'string' }
        { name: 'IncidentId', type: 'string' }
        { name: 'IsSynthetic', type: 'boolean' }
        { name: 'DataClassification', type: 'string' }
      ]
    }
  }
}

resource serviceTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: workspace
  name: 'UoiEstateService_CL'
  properties: {
    plan: 'Analytics'
    retentionInDays: retentionInDays
    schema: {
      name: 'UoiEstateService_CL'
      description: 'Synthetic business service health for the simulated insurance estate.'
      columns: [
        { name: 'TimeGenerated', type: 'dateTime' }
        { name: 'Service', type: 'string' }
        { name: 'Tier', type: 'string' }
        { name: 'HealthScore', type: 'real' }
        { name: 'UsersAffected', type: 'int' }
        { name: 'RevenueAtRiskUsd', type: 'real' }
        { name: 'IsSynthetic', type: 'boolean' }
        { name: 'DataClassification', type: 'string' }
      ]
    }
  }
}

resource costTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: workspace
  name: 'UoiEstateCost_CL'
  properties: {
    plan: 'Analytics'
    retentionInDays: retentionInDays
    schema: {
      name: 'UoiEstateCost_CL'
      description: 'Illustrative observability spend for the simulated insurance estate.'
      columns: [
        { name: 'TimeGenerated', type: 'dateTime' }
        { name: 'Tool', type: 'string' }
        { name: 'Category', type: 'string' }
        { name: 'MonthlyCostUsd', type: 'real' }
        { name: 'IngestGbPerDay', type: 'real' }
        { name: 'DuplicationPercent', type: 'real' }
        { name: 'IsSynthetic', type: 'boolean' }
        { name: 'DataClassification', type: 'string' }
      ]
    }
  }
}

resource auditTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: workspace
  name: 'UoiRemediationAudit_CL'
  properties: {
    plan: 'Analytics'
    retentionInDays: retentionInDays
    schema: {
      name: 'UoiRemediationAudit_CL'
      description: 'Audit trail of approval-gated, simulated remediation actions.'
      columns: [
        { name: 'TimeGenerated', type: 'dateTime' }
        { name: 'IncidentId', type: 'string' }
        { name: 'Action', type: 'string' }
        { name: 'TargetScope', type: 'string' }
        { name: 'ApprovedBy', type: 'string' }
        { name: 'ApprovalDecision', type: 'string' }
        { name: 'Justification', type: 'string' }
        { name: 'Executed', type: 'boolean' }
        { name: 'Outcome', type: 'string' }
        { name: 'IsSynthetic', type: 'boolean' }
        { name: 'DataClassification', type: 'string' }
      ]
    }
  }
}

/*
  One ingestion rule serving all three tables. `transformKql: 'source'` passes
  records through unmodified, which keeps the shape the generator sends
  identical to the shape an analyst queries.
*/
resource ingestionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-ingest-${baseName}'
  location: location
  tags: tags
  properties: {
    description: 'Ingestion rule for synthetic insurance estate history.'
    dataCollectionEndpointId: dataCollectionEndpointId
    streamDeclarations: {
      'Custom-UoiEstateAlert_CL': {
        columns: [
          { name: 'TimeGenerated', type: 'datetime' }
          { name: 'AlertId', type: 'string' }
          { name: 'Service', type: 'string' }
          { name: 'Component', type: 'string' }
          { name: 'Tier', type: 'string' }
          { name: 'Severity', type: 'string' }
          { name: 'Source', type: 'string' }
          { name: 'Message', type: 'string' }
          { name: 'IncidentId', type: 'string' }
          { name: 'IsSynthetic', type: 'boolean' }
          { name: 'DataClassification', type: 'string' }
        ]
      }
      'Custom-UoiEstateService_CL': {
        columns: [
          { name: 'TimeGenerated', type: 'datetime' }
          { name: 'Service', type: 'string' }
          { name: 'Tier', type: 'string' }
          { name: 'HealthScore', type: 'real' }
          { name: 'UsersAffected', type: 'int' }
          { name: 'RevenueAtRiskUsd', type: 'real' }
          { name: 'IsSynthetic', type: 'boolean' }
          { name: 'DataClassification', type: 'string' }
        ]
      }
      'Custom-UoiEstateCost_CL': {
        columns: [
          { name: 'TimeGenerated', type: 'datetime' }
          { name: 'Tool', type: 'string' }
          { name: 'Category', type: 'string' }
          { name: 'MonthlyCostUsd', type: 'real' }
          { name: 'IngestGbPerDay', type: 'real' }
          { name: 'DuplicationPercent', type: 'real' }
          { name: 'IsSynthetic', type: 'boolean' }
          { name: 'DataClassification', type: 'string' }
        ]
      }
      'Custom-UoiRemediationAudit_CL': {
        columns: [
          { name: 'TimeGenerated', type: 'datetime' }
          { name: 'IncidentId', type: 'string' }
          { name: 'Action', type: 'string' }
          { name: 'TargetScope', type: 'string' }
          { name: 'ApprovedBy', type: 'string' }
          { name: 'ApprovalDecision', type: 'string' }
          { name: 'Justification', type: 'string' }
          { name: 'Executed', type: 'boolean' }
          { name: 'Outcome', type: 'string' }
          { name: 'IsSynthetic', type: 'boolean' }
          { name: 'DataClassification', type: 'string' }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          name: 'estateDestination'
          workspaceResourceId: workspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-UoiEstateAlert_CL'
        ]
        destinations: [
          'estateDestination'
        ]
        transformKql: 'source'
        outputStream: 'Custom-UoiEstateAlert_CL'
      }
      {
        streams: [
          'Custom-UoiEstateService_CL'
        ]
        destinations: [
          'estateDestination'
        ]
        transformKql: 'source'
        outputStream: 'Custom-UoiEstateService_CL'
      }
      {
        streams: [
          'Custom-UoiEstateCost_CL'
        ]
        destinations: [
          'estateDestination'
        ]
        transformKql: 'source'
        outputStream: 'Custom-UoiEstateCost_CL'
      }
      {
        streams: [
          'Custom-UoiRemediationAudit_CL'
        ]
        destinations: [
          'estateDestination'
        ]
        transformKql: 'source'
        outputStream: 'Custom-UoiRemediationAudit_CL'
      }
    ]
  }
  dependsOn: [
    alertTable
    serviceTable
    costTable
    auditTable
  ]
}

/*
  Monitoring Metrics Publisher: the built-in role permitting writes through the
  Logs Ingestion API, scoped to this rule alone rather than the workspace.

  The grantees are the estate's own system-assigned identities, so the seeding
  job runs on a virtual machine inside the subscription and authenticates via
  IMDS. That is a deliberate choice, not a convenience: it means seeding needs
  no secret, no service principal, and no credential on the operator's
  workstation, and it works even though the subscription's directory differs
  from the one the operator's CLI is signed in to.
*/
var monitoringMetricsPublisherRoleId = '3913510d-42f4-4e42-8a64-420c390055eb'

resource ingestionRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in ingestionPrincipalIds: {
    name: guid(ingestionRule.id, principalId, monitoringMetricsPublisherRoleId)
    scope: ingestionRule
    properties: {
      roleDefinitionId: subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        monitoringMetricsPublisherRoleId
      )
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

output ingestionRuleId string = ingestionRule.id
output ingestionRuleImmutableId string = ingestionRule.properties.immutableId
output alertStreamName string = 'Custom-UoiEstateAlert_CL'
output serviceStreamName string = 'Custom-UoiEstateService_CL'
output costStreamName string = 'Custom-UoiEstateCost_CL'
