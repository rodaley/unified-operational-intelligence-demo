<#
.SYNOPSIS
    Approval-gated, SIMULATED remediation for a correlated incident.

.DESCRIPTION
    This runbook demonstrates the human approval gate required by the
    specification. Two things about it are deliberate and should not be
    "improved" away:

    1. IT CHANGES NOTHING. No service is restarted, no machine is touched, no
       configuration is altered. The remediation is simulated. What is real is
       the governance around it: the approval requirement, the refusal path and
       the audit record.

    2. IT CANNOT RUN UNSUPERVISED. There is no default approval. A caller must
       pass an explicit decision and name themselves. A scheduled trigger with
       no parameters fails closed, and a decision of anything other than
       "Approve" records a refusal and exits without acting.

    The audit record is written to UoiRemediationAudit_CL through the Logs
    Ingestion API, authenticated with the Automation account's managed identity.
    There is no secret in this runbook.

.PARAMETER IncidentId
    The correlated incident this action relates to.

.PARAMETER ApprovalDecision
    Must be exactly "Approve" for the simulated action to proceed. Any other
    value is recorded as a refusal.

.PARAMETER ApprovedBy
    The human accountable for the decision. Recorded in the audit trail.

.PARAMETER Justification
    Why the decision was made. Recorded in the audit trail.
#>
param(
    [Parameter(Mandatory = $true)][string]$IncidentId,
    [Parameter(Mandatory = $true)][string]$ApprovalDecision,
    [Parameter(Mandatory = $true)][string]$ApprovedBy,
    [string]$Justification = '',
    [Parameter(Mandatory = $true)][string]$IngestionEndpoint,
    [Parameter(Mandatory = $true)][string]$IngestionRuleId
)

$ErrorActionPreference = 'Stop'

$action = 'Restart data-tier service and re-balance connection pools'
$scope = 'vm-sql-01, vm-sql-02 (data subnet)'

Write-Output '================================================================'
Write-Output ' Unified Operational Intelligence - approval-gated remediation'
Write-Output '================================================================'
Write-Output "Incident          : $IncidentId"
Write-Output "Proposed action   : $action"
Write-Output "Target scope      : $scope"
Write-Output "Decision          : $ApprovalDecision"
Write-Output "Decision made by  : $ApprovedBy"
Write-Output ''

# The gate. Fail closed: anything that is not an explicit approval is a refusal.
$approved = $ApprovalDecision -eq 'Approve'

if (-not $approved) {
    Write-Output 'DECISION: not approved. No action taken.'
    $outcome = 'Refused - no action taken'
    $executed = $false
}
else {
    if ([string]::IsNullOrWhiteSpace($ApprovedBy)) {
        throw 'An approval must be attributable to a named person. Refusing to proceed.'
    }

    Write-Output 'DECISION: approved by a named human.'
    Write-Output ''
    Write-Output 'Executing SIMULATED remediation. Nothing is actually changed:'
    Write-Output '  [simulated] draining connections from data-tier nodes'
    Start-Sleep -Seconds 2
    Write-Output '  [simulated] restarting data-tier service'
    Start-Sleep -Seconds 2
    Write-Output '  [simulated] re-balancing connection pools'
    Start-Sleep -Seconds 2
    Write-Output '  [simulated] verifying storage latency returned below threshold'
    Write-Output ''
    Write-Output 'Simulated remediation complete. No production state was modified.'
    $outcome = 'Simulated remediation completed - no real change made'
    $executed = $true
}

# --- Audit trail -----------------------------------------------------------
# Written whether the decision was approve or refuse. A refusal is as important
# to record as an approval.

Write-Output ''
Write-Output 'Writing audit record...'

Connect-AzAccount -Identity | Out-Null

# Az versions differ in how they return the token: older releases hand back a
# plain string, newer ones a SecureString. Handle both rather than assuming,
# because the failure mode of getting this wrong is an opaque 401.
$tokenObject = Get-AzAccessToken -ResourceUrl 'https://monitor.azure.com'
if ($tokenObject.Token -is [System.Security.SecureString]) {
    $token = [System.Net.NetworkCredential]::new('', $tokenObject.Token).Password
}
else {
    $token = [string]$tokenObject.Token
}

$record = @{
    TimeGenerated      = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    IncidentId         = $IncidentId
    Action             = $action
    TargetScope        = $scope
    ApprovedBy         = $ApprovedBy
    ApprovalDecision   = $ApprovalDecision
    Justification      = $Justification
    Executed           = $executed
    Outcome            = $outcome
    IsSynthetic        = $true
    DataClassification = 'Synthetic Demo Data'
}

$uri = "$IngestionEndpoint/dataCollectionRules/$IngestionRuleId/streams/Custom-UoiRemediationAudit_CL?api-version=2023-01-01"
$body = ConvertTo-Json @($record) -Depth 5

try {
    Invoke-RestMethod -Uri $uri -Method Post `
        -Headers @{ Authorization = "Bearer $token" } `
        -ContentType 'application/json' `
        -Body $body | Out-Null
    Write-Output 'Audit record written to UoiRemediationAudit_CL.'
}
catch {
    # Surface the service's own message. An unexplained failure to write an
    # audit record is worse than a noisy one.
    $detail = $_.ErrorDetails.Message
    if (-not $detail) { $detail = $_.Exception.Message }
    Write-Error "Failed to write the audit record: $detail"
    throw
}
Write-Output ''
Write-Output "RESULT: $outcome"
