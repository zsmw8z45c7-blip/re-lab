#requires -Version 5.1
<#
.SYNOPSIS
    Remove the portable RE lab tools and download cache.

.DESCRIPTION
    Deletes tools\, downloads\, and generated configuration/report files.
    The launcher scripts and README are kept so the lab can be redeployed
    with the same one-click file.

.PARAMETER Yes
    Skip the interactive YES confirmation.

.PARAMETER DryRun
    Show what would be removed without deleting anything.
#>
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$LabRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Join-Path $LabRoot 'tools'
$DownloadsDir = Join-Path $LabRoot 'downloads'
$GeneratedFiles = @(
    (Join-Path $LabRoot 'env.ps1'),
    (Join-Path $LabRoot 'lab-manifest.json'),
    (Join-Path $LabRoot 'install-report.json'),
    (Join-Path $LabRoot 'deploy.log')
)

function Get-DirectorySize {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [int64]0 }
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return [int64]0 }
    return [int64]$sum
}

function Remove-LabPath {
    param(
        [string]$Path,
        [string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "  skip: $Label (not present)"
        return
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            Write-Host "  removed: $Label"
            return
        }
        catch {
            if ($attempt -eq 3) { throw }
            Write-Host "  retry: $Label ($($_.Exception.Message))"
            Start-Sleep -Seconds 2
        }
    }
}

Write-Host ''
Write-Host '  RE Lab - Uninstall' -ForegroundColor Cyan
Write-Host '  ==================' -ForegroundColor DarkGray
Write-Host ''
Write-Host "Location: $LabRoot"
Write-Host ''

$toolsSize = Get-DirectorySize $ToolsDir
$downloadsSize = Get-DirectorySize $DownloadsDir
$totalSize = $toolsSize + $downloadsSize
$totalGB = [math]::Round($totalSize / 1GB, 2)

Write-Host 'This will remove:'
Write-Host "  tools\      ($([math]::Round($toolsSize / 1GB, 2)) GB)"
Write-Host "  downloads\  ($([math]::Round($downloadsSize / 1GB, 2)) GB)"
Write-Host '  env.ps1, lab-manifest.json, install-report.json, deploy.log'
Write-Host ''
Write-Host ("Approximate space to free: {0:N2} GB" -f $totalGB)
Write-Host 'The launcher scripts and README will be kept for redeployment.'
Write-Host ''

if ($DryRun) {
    Write-Host 'Dry run only. Nothing was deleted.' -ForegroundColor Yellow
    exit 0
}

if (-not $Yes) {
    $answer = Read-Host 'Type YES to continue'
    if ($answer -ne 'YES') {
        Write-Host 'Cancelled. Nothing was deleted.' -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ''
Write-Host 'Stopping lab processes ...'
$prefix = $ToolsDir.TrimEnd('\') + '\'
$selfPid = $PID
$parentPid = 0
try {
    $self = Get-CimInstance Win32_Process -Filter "ProcessId = $selfPid" -ErrorAction Stop
    if ($self) { $parentPid = [int]$self.ParentProcessId }
}
catch { }

$stopped = 0
try {
    $processes = Get-CimInstance Win32_Process -ErrorAction Stop
    foreach ($process in $processes) {
        if ($process.ProcessId -eq $selfPid) { continue }
        if ($process.ProcessId -eq $parentPid) { continue }

        $exePath = [string]$process.ExecutablePath
        $commandLine = [string]$process.CommandLine
        $underTools = $exePath -and $exePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
        $referencesLab = $commandLine -and $commandLine.IndexOf($LabRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0

        if ($underTools -or $referencesLab) {
            try {
                Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
                $stopped++
            }
            catch { }
        }
    }
}
catch {
    Write-Host "  warning: could not enumerate processes: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($stopped -gt 0) {
    Write-Host "  stopped $stopped process(es)"
    Start-Sleep -Seconds 2
}
else {
    Write-Host '  no running lab processes found'
}

# Uninstall the per-user Python runtime through its original installer so
# the Add/Remove Programs entry is cleaned up too.
$pythonInstaller = Join-Path $DownloadsDir 'python-3.12.10-amd64.exe'
if (Test-Path -LiteralPath $pythonInstaller) {
    Write-Host ''
    Write-Host 'Uninstalling Python 3.12 per-user runtime ...'
    try {
        $proc = Start-Process -FilePath $pythonInstaller -ArgumentList '/uninstall /quiet' -Wait -PassThru
        Write-Host "  Python uninstaller exit code: $($proc.ExitCode)"
    }
    catch {
        Write-Host "  warning: Python uninstaller failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Removing files ...'
Remove-LabPath $ToolsDir 'tools\'
Remove-LabPath $DownloadsDir 'downloads\'

foreach ($file in $GeneratedFiles) {
    if (Test-Path -LiteralPath $file) {
        try {
            Remove-Item -LiteralPath $file -Force -ErrorAction Stop
            Write-Host "  removed: $(Split-Path $file -Leaf)"
        }
        catch {
            Write-Host "  warning: could not remove $(Split-Path $file -Leaf): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

Write-Host ''
Write-Host 'Uninstall complete.' -ForegroundColor Green
Write-Host "Freed approximately $([math]::Round($totalGB, 2)) GB."
Write-Host 'The launcher scripts are still here; run the deploy script to reinstall.'
exit 0
