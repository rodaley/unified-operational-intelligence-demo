targetScope = 'resourceGroup'

/*
  Azure Automation, hosting the approval-gated remediation runbook.

  The reason this exists at all is to make the human approval gate a *real*
  artifact rather than a claim on a slide. An audience can open the runbook in
  the portal, see that it takes a mandatory approval decision, run it, and watch
  the refusal path and the approval path produce different audit records.

  The runbook changes nothing. See scripts/Invoke-ApprovedRemediation.ps1.

  The account uses a system-assigned identity and holds no credential. Its
  identity is granted publish rights on the ingestion rule so it can write its
  audit trail, and nothing else.
*/

param baseName string
param location string
param tags object

resource automation 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: 'aa-${baseName}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    // No stored credentials, and local authentication disabled: the account
    // acts only as its managed identity.
    disableLocalAuth: true
    publicNetworkAccess: true
  }
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automation
  name: 'Invoke-ApprovedRemediation'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: true
    logVerbose: false
    description: 'Approval-gated SIMULATED remediation. Changes nothing. Requires an explicit, attributable human decision and writes an audit record for both approval and refusal.'
  }
}

output automationAccountName string = automation.name
output automationPrincipalId string = automation.identity.principalId
output runbookName string = runbook.name
