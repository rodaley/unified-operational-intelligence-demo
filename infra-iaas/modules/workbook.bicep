targetScope = 'resourceGroup'

/*
  The Azure Monitor Workbook that is the demonstration surface.

  This is the deliberate centre of the IaaS design: the executive-facing view
  lives *inside the Azure Portal*, built from native Azure Monitor components,
  rather than in a bespoke web application deployed alongside it. Nothing here
  renders a chart that Azure Monitor could not already render; the contribution
  is the arrangement, the narrative ordering, and the labelling discipline.

  The workbook body is kept in a separate .json file rather than inlined,
  because it is authored and previewed in the portal's workbook editor and
  round-trips cleanly that way.
*/

param baseName string
param location string
param tags object
param workspaceId string

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  // Workbook names must be a GUID. Deriving it from the resource group and a
  // fixed seed keeps redeployment idempotent: the same workbook is updated in
  // place rather than a duplicate being created next to it.
  name: guid(resourceGroup().id, 'uoi-workbook', baseName)
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: 'Unified Operational Intelligence'
    category: 'workbook'
    sourceId: workspaceId
    version: '1.0'
    serializedData: loadTextContent('../workbooks/uoi-workbook.json')
  }
}

output workbookId string = workbook.id
output workbookName string = workbook.name
