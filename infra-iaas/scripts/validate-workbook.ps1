<#
.SYNOPSIS
    Validate every KQL query embedded in the workbook against the live workspace.

.DESCRIPTION
    A workbook that deploys successfully can still be full of broken queries:
    ARM validates the JSON, not the KQL inside it. This script extracts every
    query from the workbook definition and runs it, so a query error is found
    here rather than on a screen in front of an audience.

    Queries are rewritten to substitute a concrete time filter for the
    workbook's {TimeRange} parameter, which only exists at render time.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SubscriptionId,
    # Resolved from the deployment when not supplied, so this script is portable
    # between tenants rather than pinned to one workspace.
    [string]$WorkspaceCustomerId,
    [int]$TimeRangeHours = 24,
    [string]$WorkbookPath = "$PSScriptRoot\..\workbooks\uoi-workbook.json",
    [string]$ResourceGroup = 'rg-uoi-iaas',
    [string]$WorkspaceName = 'log-uoi'
)

$ErrorActionPreference = 'Stop'

if (-not $WorkspaceCustomerId) {
    Write-Host "Resolving workspace $WorkspaceName in $ResourceGroup ..."
    $WorkspaceCustomerId = az monitor log-analytics workspace show `
        --subscription $SubscriptionId -g $ResourceGroup -n $WorkspaceName `
        --query customerId -o tsv
    if (-not $WorkspaceCustomerId) {
        throw "Could not resolve the workspace GUID. Pass -WorkspaceCustomerId explicitly."
    }
}

$workbook = Get-Content $WorkbookPath -Raw | ConvertFrom-Json

function Get-Queries {
    param($items, $path)
    foreach ($item in $items) {
        $name = if ($item.name) { $item.name } else { 'unnamed' }
        if ($item.type -eq 3 -and $item.content.query) {
            [pscustomobject]@{ Name = "$path/$name"; Query = $item.content.query }
        }
        if ($item.type -eq 12 -and $item.content.items) {
            Get-Queries -items $item.content.items -path "$path/$name"
        }
    }
}

$queries = @(Get-Queries -items $workbook.items -path '')

Write-Host "found $($queries.Count) queries to validate"
Write-Host ''

# The first data-plane call from a cold process reliably pays a startup cost
# large enough to hit the client read timeout, which then gets misreported as a
# failure of whichever query happened to run first. Warm the connection with a
# trivial query so a real one never absorbs that cost.
Write-Host 'warming up connection...'
az monitor log-analytics query `
    --workspace $WorkspaceCustomerId `
    --subscription $SubscriptionId `
    --analytics-query 'print 1' `
    -o json 2>&1 | Out-Null
Write-Host ''

$failed = 0
foreach ($entry in $queries) {
    # The az CLI mangles multi-line values passed to --analytics-query, which
    # surfaces as a generic BadArgumentError that looks like a KQL fault but is
    # not. Flattening to a single line (dropping // comments, which would
    # otherwise swallow the rest of the query) sends exactly the same KQL the
    # portal sends.
    $lines = $entry.Query -split "`r?`n" |
        ForEach-Object { ($_ -replace '//.*$', '').Trim() } |
        Where-Object { $_ }

    # Every query item is bound to the shared TimeRange parameter, so the portal
    # always supplies a time context. Nothing supplies one here, which means raw
    # platform tables are scanned over full retention and the request times out
    # on the client. Injecting the default window reproduces render-time
    # behaviour rather than testing a case the workbook never issues.
    $bounded = @()
    $injected = $false
    foreach ($line in $lines) {
        $bounded += $line
        if (-not $injected -and $line -match '^[A-Za-z_][A-Za-z0-9_]*$') {
            $bounded += "| where TimeGenerated > ago($TimeRangeHours" + 'h)'
            $injected = $true
        }
    }
    if (-not $injected) {
        Write-Host "WARN  $($entry.Name): no table reference found to time-bound"
    }
    $query = $bounded -join ' '

    # Running 17 queries back to back against one workspace intermittently
    # produces a client read timeout on a query that succeeds in a few seconds
    # in isolation. That is contention, not a broken query, so a single retry
    # is attempted before reporting a failure. A validator that reports false
    # failures stops being trusted, which defeats its purpose.
    $result = $null
    foreach ($attempt in 1..2) {
        $result = az monitor log-analytics query `
            --workspace $WorkspaceCustomerId `
            --subscription $SubscriptionId `
            --analytics-query $query `
            -o json 2>&1

        if ($LASTEXITCODE -eq 0) { break }
        if ($attempt -eq 1) {
            Write-Host "retry $($entry.Name) (first attempt failed)"
            Start-Sleep -Seconds 10
        }
    }

    if ($LASTEXITCODE -ne 0) {
        $failed++
        Write-Host "FAIL  $($entry.Name)" -ForegroundColor Red
        Write-Host "      $($result | Select-Object -First 3)"
    }
    else {
        $rows = 0
        try { $rows = (@($result | ConvertFrom-Json)).Count } catch { $rows = -1 }
        Write-Host "ok    $($entry.Name)  (rows: $rows)"
    }
}

Write-Host ''
if ($failed -gt 0) {
    Write-Host "$failed of $($queries.Count) queries FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "all $($queries.Count) workbook queries executed successfully"
