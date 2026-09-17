targetScope = 'resourceGroup'

/*
  A shared Azure Portal dashboard.

  The workbook is the analytical surface; this is the landing surface. It is
  what a viewer sees on opening the portal, and its job is to establish three
  things within a few seconds: the estate is real and reporting, the data is
  labelled synthetic, and there is one link to the detailed narrative.

  Metric tiles here read from the virtual machines' platform metrics directly,
  which is deliberate. It demonstrates that the estate is observable natively
  without any agent configuration at all, before the workbook goes on to show
  what the agent adds on top.
*/

param baseName string
param location string
param tags object
param vmIds array
param workbookId string

var headerMarkdown = '''
# Unified Operational Intelligence

**A simulated insurance estate, observed entirely with native Azure Monitor.**

Six Linux virtual machines across three tiers — web, application and data — in a
private virtual network with no public inbound access. Telemetry is collected by
the Azure Monitor Agent through Data Collection Rules into a single Log Analytics
workspace.

---

**Synthetic Demo Data.** The machines and their telemetry are real. The business
context layered over them — services, alert history, impact and spend — is
generated for demonstration. Every synthetic record carries `IsSynthetic = true`.

All financial figures are **Illustrative Sample Data, not a customer estimate.**
'''

var narrativeMarkdown = '''
## Open the full narrative

The **Unified Operational Intelligence** workbook is the guided view:

1. **Estate health** — live telemetry from the six machines
2. **Incident correlation** — 150 related alerts correlated into 1 actionable incident
3. **Business impact** — which services degraded, and what that costs
4. **Observability spend** — where monitoring data is duplicated across tools
5. **Response** — a proposed remediation, held for human approval

Find it under **Monitor > Workbooks**, or in this resource group's **Workbooks**
blade.

---

*No autonomous remediation is performed anywhere in this demonstration. Proposed
actions are presented with their evidence and await a human decision.*
'''

resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: 'dash-${baseName}'
  location: location
  tags: union(tags, {
    'hidden-title': 'Unified Operational Intelligence'
  })
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: { x: 0, y: 0, colSpan: 7, rowSpan: 5 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: headerMarkdown
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                  }
                }
              }
            }
          }
          {
            position: { x: 7, y: 0, colSpan: 5, rowSpan: 5 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: narrativeMarkdown
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                  }
                }
              }
            }
          }
          {
            position: { x: 0, y: 5, colSpan: 6, rowSpan: 4 }
            metadata: {
              // Bicep's type model for dashboard parts narrows "type" to the
              // first part kind it sees (MarkdownPart) and then rejects the
              // others. This is an acknowledged type-definition inaccuracy, not
              // an error in this template: the part type below is the correct,
              // documented one and deploys successfully.
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      title: 'CPU utilisation across the estate (live platform metrics)'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2 }
                        axisVisualization: {
                          x: { isVisible: true, axisType: 2 }
                          y: { isVisible: true, axisType: 1 }
                        }
                      }
                      timespan: { relative: { duration: 14400000 } }
                      metrics: [
                        for vmId in vmIds: {
                          resourceMetadata: { id: vmId }
                          name: 'Percentage CPU'
                          aggregationType: 4
                          namespace: 'microsoft.compute/virtualmachines'
                          metricVisualization: { displayName: 'CPU %' }
                        }
                      ]
                    }
                  }
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
            }
          }
          {
            position: { x: 6, y: 5, colSpan: 6, rowSpan: 4 }
            metadata: {
              // Bicep's type model for dashboard parts narrows "type" to the
              // first part kind it sees (MarkdownPart) and then rejects the
              // others. This is an acknowledged type-definition inaccuracy, not
              // an error in this template: the part type below is the correct,
              // documented one and deploys successfully.
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      title: 'Network throughput across the estate (live platform metrics)'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2 }
                        axisVisualization: {
                          x: { isVisible: true, axisType: 2 }
                          y: { isVisible: true, axisType: 1 }
                        }
                      }
                      timespan: { relative: { duration: 14400000 } }
                      metrics: [
                        for vmId in vmIds: {
                          resourceMetadata: { id: vmId }
                          name: 'Network In Total'
                          aggregationType: 1
                          namespace: 'microsoft.compute/virtualmachines'
                          metricVisualization: { displayName: 'Network in' }
                        }
                      ]
                    }
                  }
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
            }
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: { relative: { duration: 24, timeUnit: 1 } }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
      }
    }
  }
}

output dashboardId string = dashboard.id
// Surfaced so the deployment output can point an operator straight at it.
output workbookReference string = workbookId
