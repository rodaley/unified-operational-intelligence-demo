targetScope = 'resourceGroup'

/*
  Azure Monitor alert rules for the estate.

  Two kinds, and the distinction is the point of the demonstration.

  Metric alerts fire from genuine machine conditions. When a presenter drives CPU
  up on a virtual machine, these rules evaluate real platform metrics and produce
  a real alert. Nothing is staged.

  The scheduled query rule is the unification step. It reads the synthetic estate
  history and groups alerts by their correlation key, surfacing the count of
  related alerts gathered into a single actionable incident. The phrasing matters:
  these are related alerts correlated into one incident, not false positives, and
  correlation here indicates relationship, not proven causation.
*/

param baseName string
param location string
param tags object
param actionGroupId string
param workspaceId string

@description('Resource IDs of the estate virtual machines the metric rules evaluate.')
param vmIds array

@description('Count of related alerts sharing one correlation key before the incident rule fires.')
param correlationThreshold int = 25

resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-estate-cpu-${baseName}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Sustained processor pressure on a synthetic insurance estate virtual machine.'
    severity: 2
    enabled: true
    scopes: vmIds
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Compute/virtualMachines'
    targetResourceRegion: location
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCpu'
          criterionType: 'StaticThresholdCriterion'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

resource lowMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-estate-memory-${baseName}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Available memory exhausted on a synthetic insurance estate virtual machine.'
    severity: 2
    enabled: true
    scopes: vmIds
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Compute/virtualMachines'
    targetResourceRegion: location
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'LowMemory'
          criterionType: 'StaticThresholdCriterion'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          metricName: 'Available Memory Bytes'
          operator: 'LessThan'
          threshold: 209715200
          timeAggregation: 'Average'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

/*
  The correlation rule. Related alerts across the estate share an IncidentId;
  when enough of them accumulate under one key, this raises a single incident
  rather than a page per alert.
*/
resource correlatedIncidentAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-correlated-incident-${baseName}'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Related estate alerts correlated into an actionable incident'
    description: 'Groups related synthetic estate alerts by correlation key and raises one incident for the group. Correlation indicates relationship, not proven causation.'
    severity: 1
    enabled: true
    scopes: [
      workspaceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT30M'
    criteria: {
      allOf: [
        {
          query: 'UoiEstateAlert_CL\n| where IsSynthetic == true\n| where isnotempty(IncidentId)\n| summarize RelatedAlerts = count() by IncidentId\n| where RelatedAlerts >= ${correlationThreshold}'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        actionGroupId
      ]
    }
  }
}

output highCpuAlertId string = highCpuAlert.id
output lowMemoryAlertId string = lowMemoryAlert.id
output correlatedIncidentAlertId string = correlatedIncidentAlert.id
