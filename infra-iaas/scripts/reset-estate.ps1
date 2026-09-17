<#
.SYNOPSIS
    Reset the synthetic estate history to a clean slate.

.DESCRIPTION
    Deletes the synthetic custom tables, then redeploys the Bicep template to
    recreate them empty. Seeding afterwards produces a clean, single-storm
    dataset.

    WHY TABLE DELETION RATHER THAN THE PURGE API
    --------------------------------------------
    The obvious approach is the Log Analytics purge API, and it does work in the
    sense that requests are accepted and return operation IDs. The problem is
    latency: measured against this workspace, three purge operations remained in
    "pending" for well over an hour and the rows stayed queryable throughout.
    Azure documents purge as a long-running background operation, which makes it
    unsuitable for resetting a demonstration shortly before presenting it.

    Deleting the custom table removes its data immediately, and because the
    tables are declared in Bicep they are trivially recreated. Real telemetry
    (InsightsMetrics, Syslog, Heartbeat) lives in platform tables and is never
    touched by this script.

.EXAMPLE
    ./reset-estate.ps1 -SubscriptionId <id>
    # then re-run seed-estate.py from an estate VM
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SubscriptionId,
    [string]$ResourceGroup = 'rg-uoi-iaas',
    [string]$WorkspaceName = 'log-uoi',
    [switch]$SkipRedeploy,
    [string]$AdminPublicKeyPath = "$env:USERPROFILE\.ssh\uoi-iaas-demo.pub"
)

$ErrorActionPreference = 'Stop'

$tables = @(
    'UoiEstateAlert_CL',
    'UoiEstateService_CL',
    'UoiEstateCost_CL',
    'UoiRemediationAudit_CL'
)

$base = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup" +
        "/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName"

foreach ($table in $tables) {
    Write-Host "deleting $table"
    az rest --method delete --url "$base/tables/$table`?api-version=2023-09-01" -o none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  delete returned a non-zero exit code for $table (it may not have existed)"
    }
}

Write-Host ''
Write-Host 'waiting for table deletion to settle'
Start-Sleep -Seconds 30

if ($SkipRedeploy) {
    Write-Host 'RESET_COMPLETE tables deleted; redeploy skipped by request'
    exit 0
}

if (-not (Test-Path $AdminPublicKeyPath)) {
    throw "SSH public key not found at $AdminPublicKeyPath. Pass -AdminPublicKeyPath."
}

$publicKey = (Get-Content $AdminPublicKeyPath -Raw).Trim()
$templatePath = Join-Path $PSScriptRoot '..\main.bicep'

Write-Host 'redeploying to recreate the tables'
az deployment sub create `
    --name "uoi-reset-$(Get-Date -Format yyyyMMddHHmmss)" `
    --location eastus2 `
    --subscription $SubscriptionId `
    --template-file $templatePath `
    --parameters adminPublicKey="$publicKey" `
    --query 'properties.provisioningState' -o tsv

if ($LASTEXITCODE -ne 0) {
    throw 'redeploy failed; tables may not have been recreated'
}

Write-Host ''
Write-Host 'RESET_COMPLETE tables recreated empty. Re-run seed-estate.py to populate.'
