#requires -Version 5.1
<#
.SYNOPSIS
    Verify that the portable RE lab is complete and report versions.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$LabRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $LabRoot 'env.ps1'
$ManifestFile = Join-Path $LabRoot 'lab-manifest.json'

if (Test-Path -LiteralPath $EnvFile) {
    . $EnvFile
}

if (-not (Test-Path -LiteralPath $ManifestFile)) {
    Write-Host 'lab-manifest.json is missing; deploy first.' -ForegroundColor Red
    exit 1
}

$tools = (Get-Content -LiteralPath $ManifestFile -Raw) | ConvertFrom-Json
if ($tools -isnot [System.Array]) {
    $tools = @($tools)
}
$rows = foreach ($tool in $tools) {
    $exists = Test-Path -LiteralPath $tool.path
    $version = ''
    if ($exists) {
        try {
            switch ($tool.name) {
                'Python' { $version = (& $tool.path --version 2>&1 | Select-Object -First 1) }
                'Node.js' { $version = (& $tool.path --version 2>&1 | Select-Object -First 1) }
                'radare2' { $version = (& $tool.path -v 2>&1 | Select-Object -First 1) }
                default { $version = '' }
            }
        }
        catch {
            $version = ''
        }
    }
    [pscustomobject]@{
        tool    = $tool.name
        exists  = $exists
        version = $version
        path    = $tool.path
    }
}

$rows | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
$missing = @($rows | Where-Object { -not $_.exists })
if ($missing.Count -gt 0) {
    Write-Host ("Missing tools: {0}" -f (($missing | ForEach-Object { $_.tool }) -join ', ')) -ForegroundColor Yellow
    exit 1
}

Write-Host 'All manifest entries are present.' -ForegroundColor Green
exit 0
