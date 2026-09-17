targetScope = 'resourceGroup'

/*
  Data collection rules for the estate.

  Two rules, deliberately separated so a presenter can point at each one in the
  portal and say what it does:

  1. VM Insights. Performance counters plus the Dependency Agent's connection
     data. This is the rule that populates the native Insights blade on every
     virtual machine, including the Performance charts and the dependency Map.

  2. Syslog. Standard Linux facilities at warning and above, which gives the
     estate a stream of genuine operating-system events to correlate against.

  Associations are created per machine. The association is the link an operator
  can follow in the portal from a virtual machine back to the rule governing
  what it collects, which is worth showing: collection is declarative
  configuration, not agent-side guesswork.
*/

param baseName string
param location string
param tags object
param workspaceId string

@description('Names of the estate virtual machines to associate the rules with.')
param vmNames array

resource vmInsightsRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-vminsights-${baseName}'
  location: location
  tags: tags
  kind: 'Linux'
  properties: {
    description: 'VM Insights performance counters and dependency map data for the synthetic insurance estate.'
    dataSources: {
      performanceCounters: [
        {
          name: 'VMInsightsPerfCounters'
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\VmInsights\\DetailedMetrics'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'vmInsightsDestination'
          workspaceResourceId: workspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'vmInsightsDestination'
        ]
      }
    ]
  }
}

resource syslogRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-syslog-${baseName}'
  location: location
  tags: tags
  kind: 'Linux'
  properties: {
    description: 'Operating system events from the synthetic insurance estate.'
    dataSources: {
      syslog: [
        {
          name: 'estateSyslog'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'cron'
            'daemon'
            'kern'
            'syslog'
            'user'
          ]
          logLevels: [
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'syslogDestination'
          workspaceResourceId: workspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          'syslogDestination'
        ]
      }
    ]
  }
}

resource estateVms 'Microsoft.Compute/virtualMachines@2024-07-01' existing = [
  for name in vmNames: {
    name: name
  }
]

resource vmInsightsAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = [
  for (name, index) in vmNames: {
    name: 'dcra-vminsights'
    scope: estateVms[index]
    properties: {
      description: 'Collects VM Insights performance and dependency data.'
      dataCollectionRuleId: vmInsightsRule.id
    }
  }
]

resource syslogAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = [
  for (name, index) in vmNames: {
    name: 'dcra-syslog'
    scope: estateVms[index]
    properties: {
      description: 'Collects operating system events.'
      dataCollectionRuleId: syslogRule.id
    }
  }
]

output vmInsightsRuleId string = vmInsightsRule.id
output syslogRuleId string = syslogRule.id
