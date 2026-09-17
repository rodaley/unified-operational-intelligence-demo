# Redacts identifying information from Azure Portal screenshots so the
# walkthrough can be shared outside the tenant.
#
# Removes the signed-in account chip and directory name from the top-right of
# the portal header on every frame, plus any extra regions declared below.
#
# Reads from shots\, writes to shots-redacted\. Never edits in place, so the
# originals remain available for internal use.

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root 'shots'
$out  = Join-Path $root 'shots-redacted'
New-Item -ItemType Directory -Force -Path $out | Out-Null

# Every frame in the document is a 1680x950 portal capture.
$identityChip = @{ X = 1444; Y = 0; W = 198; H = 44 }

# Additional regions to cover, keyed by screenshot name. The resource group
# Essentials panel prints the subscription name - which contains the operator's
# alias - and the full subscription ID.
$extra = @{
    '01-resource-group' = @(
        @{ X = 470; Y = 217; W = 250; H = 20 },   # Subscription name
        @{ X = 470; Y = 246; W = 250; H = 20 }    # Subscription ID
    )
}

$shots = @(
    '01-resource-group', '02-dashboard', '03-workbook-estate',
    '03b-workbook-estate-cpu', '04-workbook-incident',
    '04b-workbook-incident-detail', '05-workbook-impact', '06-workbook-spend',
    '07-workbook-response', '08-vm-insights', '09-alerts', '10-logs',
    '11-runbooks', 'agent5-final', 'agent3-final'
)

$done = 0
foreach ($name in $shots) {
    $inPath = Join-Path $src "$name.png"
    if (-not (Test-Path $inPath)) { Write-Host "SKIP  $name (not found)"; continue }

    $img = [System.Drawing.Image]::FromFile($inPath)
    $bmp = New-Object System.Drawing.Bitmap $img.Width, $img.Height
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($img, 0, 0, $img.Width, $img.Height)

    # Match the portal header colour so the redaction reads as empty chrome
    # rather than a black bar drawn over something interesting. Sample between
    # the "Microsoft Azure" wordmark and the search box, which is always header
    # blue - x=1200 lands on the Copilot button.
    $header = $bmp.GetPixel(420, 20)
    $brush  = New-Object System.Drawing.SolidBrush $header
    $g.FillRectangle($brush, $identityChip.X, $identityChip.Y, $identityChip.W, $identityChip.H)

    foreach ($r in $extra[$name]) {
        $c = $bmp.GetPixel([Math]::Max($r.X - 12, 0), $r.Y + [int]($r.H / 2))
        $b2 = New-Object System.Drawing.SolidBrush $c
        $g.FillRectangle($b2, $r.X, $r.Y, $r.W, $r.H)
        $b2.Dispose()
    }

    $g.Dispose()
    $bmp.Save((Join-Path $out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose(); $img.Dispose(); $brush.Dispose()
    Write-Host "OK    $name"
    $done++
}

Write-Host ""
Write-Host "Wrote $done redacted frames to $out"
