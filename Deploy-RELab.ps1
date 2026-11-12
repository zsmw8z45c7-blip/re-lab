#requires -Version 5.1
<#
.SYNOPSIS
    One-click installer for a portable Windows reverse-engineering lab.

.DESCRIPTION
    Downloads portable/open-source tools into .\tools, creates .\env.ps1 and
    .\lab-manifest.json, and leaves the machine-wide configuration untouched.

.PARAMETER DryRun
    Print the download plan without downloading anything.

.PARAMETER Force
    Re-download and re-extract tools that are already present.

.PARAMETER SkipPython
    Do not install the embedded Python runtime and Python packages.

.PARAMETER SkipNode
    Do not install the portable Node.js runtime and npm tools.

.PARAMETER IncludeAngr
    Also install angr (large, optional, may fail on some Windows setups).
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipPython,
    [switch]$SkipNode,
    [switch]$IncludeAngr,
    [switch]$NoProxy
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

$LabRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Join-Path $LabRoot 'tools'
$DownloadsDir = Join-Path $LabRoot 'downloads'
$EnvFile = Join-Path $LabRoot 'env.ps1'
$ManifestFile = Join-Path $LabRoot 'lab-manifest.json'
$ReportFile = Join-Path $LabRoot 'install-report.json'
$LogFile = Join-Path $LabRoot 'deploy.log'

$GhidraUrl = 'https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.2_build/ghidra_12.2_PUBLIC_20261016.zip'
$JdkUrl = 'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/25/jdk/x64/windows/OpenJDK25U-jdk_x64_windows_hotspot_25.0.5_8.zip'
$JdkFallbackUrl = 'https://api.adoptium.net/v3/binary/latest/25/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk'
$Radare2Url = 'https://github.com/radareorg/radare2/releases/download/6.2.6/radare2-6.2.6-w64.zip'
$CutterUrl = 'https://github.com/rizinorg/cutter/releases/download/v2.5.0/Cutter-v2.5.0-Windows-x86_64.zip'
$X64dbgUrl = 'https://github.com/x64dbg/x64dbg/releases/download/2026.05.27/snapshot_2026-05-27_12-11.zip'
$JadxUrl = 'https://github.com/skylot/jadx/releases/download/v1.5.6/jadx-gui-1.5.6-with-jre-win.zip'
$ApktoolUrl = 'https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar'
$ILSpyUrl = 'https://github.com/icsharpcode/ILSpy/releases/download/v11.2/ILSpy_windows_11.2.0.10050-x64.zip'
$DnSpyUrl = 'https://github.com/dnSpyEx/dnSpy/releases/download/v6.6.0/dnSpy-net-win64.zip'
$ImHexUrl = 'https://github.com/WerWolv/ImHex/releases/download/v1.38.1/imhex-1.38.1-Windows-Portable-x86_64.zip'
$KaitaiUrl = 'https://github.com/kaitai-io/kaitai_struct_compiler/releases/download/0.11/kaitai-struct-compiler-0.11.zip'
$PythonUrl = 'https://mirrors.tuna.tsinghua.edu.cn/python/3.12.10/python-3.12.10-amd64.exe'
$PythonFallbackUrl = 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe'
$NodeUrl = 'https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/v22.14.0/node-v22.14.0-win-x64.zip'
$NodeFallbackUrl = 'https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip'
$PipIndex = 'https://pypi.tuna.tsinghua.edu.cn/simple'
$NpmRegistry = 'https://registry.npmmirror.com'
$GitHubProxy = 'https://ghproxy.imciel.com/'
$script:UseProxy = -not $NoProxy

$script:Report = New-Object System.Collections.Generic.List[object]
$script:ExtraPath = New-Object System.Collections.Generic.List[string]
$script:JavaHome = ''
$script:Entries = New-Object System.Collections.Generic.List[object]

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "    OK: $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    WARN: $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "    ERROR: $Message" -ForegroundColor Red
}

function Add-Report {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Path = '',
        [string]$Version = '',
        [string]$ErrorText = ''
    )
    $script:Report.Add([pscustomobject]@{
        name    = $Name
        status  = $Status
        version = $Version
        path    = $Path
        error   = $ErrorText
    })
}

function Add-LabPath {
    param([string]$Path)
    if ($Path -and -not $script:ExtraPath.Contains($Path)) {
        $script:ExtraPath.Add($Path)
    }
}

function Find-File {
    param([string]$Root, [string]$Name)
    if (-not (Test-Path -LiteralPath $Root)) { return $null }
    $item = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Name -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($item) { return $item.FullName }
    return $null
}

function Get-RemoteFile {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Label,
        [string]$FallbackUri = '',
        [string]$Sha256 = ''
    )

    if ((Test-Path -LiteralPath $OutFile) -and -not $Force) {
        $existing = (Get-Item -LiteralPath $OutFile).Length
        if ($existing -gt 1MB) {
            if ($Sha256) {
                $hash = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash.ToLower()
                if ($hash -ne $Sha256.ToLower()) {
                    Write-Warn 'cached file hash mismatch; downloading again'
                    Remove-Item -LiteralPath $OutFile -Force
                }
                else {
                    Write-Host ("    cached: {0} ({1:N1} MB)" -f (Split-Path $OutFile -Leaf), ($existing / 1MB))
                    return
                }
            }
            else {
                Write-Host ("    cached: {0} ({1:N1} MB)" -f (Split-Path $OutFile -Leaf), ($existing / 1MB))
                return
            }
        }
    }

    $part = "$OutFile.part"
    $urls = @($Uri)
    if ($FallbackUri) { $urls += $FallbackUri }
    $lastError = ''

    foreach ($url in $urls) {
        if (Test-Path -LiteralPath $part) {
            Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        }

        Write-Host ("    downloading {0} ..." -f $Label)
        & curl.exe -L --fail --silent --show-error --retry 3 --retry-delay 2 --connect-timeout 30 -o $part $url
        if ($LASTEXITCODE -ne 0) {
            $lastError = "curl exited with code $LASTEXITCODE for $url"
            Write-Warn $lastError
            continue
        }
        if (-not (Test-Path -LiteralPath $part)) {
            $lastError = "download did not produce a file: $url"
            Write-Warn $lastError
            continue
        }
        $size = (Get-Item -LiteralPath $part).Length
        if ($size -lt 1024) {
            $lastError = "download is unexpectedly small ($size bytes): $url"
            Write-Warn $lastError
            continue
        }
        if ($Sha256) {
            $hash = (Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash.ToLower()
            if ($hash -ne $Sha256.ToLower()) {
                $lastError = "SHA256 mismatch for $url"
                Write-Warn $lastError
                Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
                continue
            }
        }
        Move-Item -LiteralPath $part -Destination $OutFile -Force
        Write-Host ("    saved: {0:N1} MB" -f ($size / 1MB))
        return
    }

    throw $lastError
}

function Get-GitHubAsset {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Label,
        [string]$Sha256 = ''
    )

    $primary = $Uri
    if ($script:UseProxy -and $Uri -like 'https://github.com/*') {
        $primary = $GitHubProxy + $Uri
    }
    Get-RemoteFileFast -Uri $primary -OutFile $OutFile -Label $Label -Sha256 $Sha256 -FallbackUri $Uri
}

function Get-RemoteFileFast {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Label,
        [string]$Sha256 = '',
        [string]$FallbackUri = '',
        [int]$Connections = 4
    )

    if ((Test-Path -LiteralPath $OutFile) -and -not $Force) {
        $existing = (Get-Item -LiteralPath $OutFile).Length
        if ($existing -gt 1MB) {
            if ($Sha256) {
                $hash = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash.ToLower()
                if ($hash -eq $Sha256.ToLower()) {
                    Write-Host ("    cached: {0} ({1:N1} MB)" -f (Split-Path $OutFile -Leaf), ($existing / 1MB))
                    return
                }
                Write-Warn 'cached file hash mismatch; downloading again'
                Remove-Item -LiteralPath $OutFile -Force
            }
            else {
                Write-Host ("    cached: {0} ({1:N1} MB)" -f (Split-Path $OutFile -Leaf), ($existing / 1MB))
                return
            }
        }
    }

    $urls = @($Uri)
    if ($FallbackUri) { $urls += $FallbackUri }

    foreach ($url in $urls) {
        $partDir = $null
        try {
            Write-Host ("    downloading {0} (parallel) ..." -f $Label)

            $head = & curl.exe -L -sI --fail --connect-timeout 30 $url
            if ($LASTEXITCODE -ne 0) {
                throw "HEAD request failed for $url"
            }
            $length = [int64]0
            foreach ($line in $head) {
                if ($line -match '^(?i)content-length:\s*(\d+)') {
                    $length = [int64]$Matches[1]
                }
            }
            if ($length -lt 1MB) {
                throw "invalid content length ($length) for $url"
            }

            $probe = Join-Path $env:TEMP ("relab-probe-" + [guid]::NewGuid().ToString('N') + ".bin")
            $code = [string](& curl.exe -L -s -o $probe -w '%{http_code}' -r 0-0 $url)
            $probeOk = (Test-Path -LiteralPath $probe) -and ((Get-Item -LiteralPath $probe).Length -eq 1)
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            if ($code -notmatch '206' -or -not $probeOk) {
                throw "server does not support byte ranges (HTTP $code)"
            }

            $partDir = Join-Path $DownloadsDir ("parts-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $partDir -Force | Out-Null
            $chunk = [int64][math]::Ceiling($length / $Connections)
            $parts = @()
            for ($i = 0; $i -lt $Connections; $i++) {
                $start = [int64]$i * $chunk
                if ($start -ge $length) { break }
                $end = [math]::Min($start + $chunk - 1, $length - 1)
                $partPath = Join-Path $partDir ("part{0:D2}.bin" -f $i)
                $parts += [pscustomobject]@{
                    Index    = $i
                    Path     = $partPath
                    Start    = $start
                    End      = $end
                    Expected = ($end - $start + 1)
                }
            }

            $processes = @()
            foreach ($part in $parts) {
                $curlArgs = @(
                    '-L', '--fail', '--silent', '--show-error',
                    '--retry', '3', '--retry-delay', '2', '--connect-timeout', '30', '--max-time', '900',
                    '-r', ("$($part.Start)-$($part.End)"), '-o', $part.Path, $url
                )
                $processes += Start-Process -FilePath curl.exe -ArgumentList $curlArgs -PassThru -NoNewWindow
            }
            foreach ($process in $processes) {
                if (-not $process.HasExited) {
                    $process.WaitForExit()
                }
            }

            $bad = @($parts | Where-Object {
                -not (Test-Path -LiteralPath $_.Path) -or
                (Get-Item -LiteralPath $_.Path).Length -ne $_.Expected
            })
            if ($bad.Count -gt 0) {
                foreach ($part in $bad) {
                    Remove-Item -LiteralPath $part.Path -Force -ErrorAction SilentlyContinue
                    $curlArgs = @(
                        '-L', '--fail', '--silent', '--show-error',
                        '--retry', '3', '--retry-delay', '2', '--connect-timeout', '30', '--max-time', '900',
                        '-r', ("$($part.Start)-$($part.End)"), '-o', $part.Path, $url
                    )
                    & curl.exe @curlArgs
                }
                $bad = @($parts | Where-Object {
                    -not (Test-Path -LiteralPath $_.Path) -or
                    (Get-Item -LiteralPath $_.Path).Length -ne $_.Expected
                })
                if ($bad.Count -gt 0) {
                    throw "parallel download incomplete ($($bad.Count) parts)"
                }
            }

            $parallelOut = "$OutFile.parallel"
            if (Test-Path -LiteralPath $parallelOut) {
                Remove-Item -LiteralPath $parallelOut -Force
            }
            $outStream = [System.IO.File]::Create($parallelOut)
            try {
                foreach ($part in ($parts | Sort-Object Index)) {
                    $inStream = [System.IO.File]::OpenRead($part.Path)
                    try {
                        $inStream.CopyTo($outStream)
                    }
                    finally {
                        $inStream.Dispose()
                    }
                }
            }
            finally {
                $outStream.Dispose()
            }

            $actual = (Get-Item -LiteralPath $parallelOut).Length
            if ($actual -ne $length) {
                throw "size mismatch: got $actual bytes, expected $length"
            }
            if ($Sha256) {
                $hash = (Get-FileHash -LiteralPath $parallelOut -Algorithm SHA256).Hash.ToLower()
                if ($hash -ne $Sha256.ToLower()) {
                    throw "SHA256 mismatch for $Label"
                }
            }

            Move-Item -LiteralPath $parallelOut -Destination $OutFile -Force
            Remove-Item -LiteralPath $partDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host ("    saved: {0:N1} MB" -f ($actual / 1MB))
            return
        }
        catch {
            Write-Warn $_.Exception.Message
            if ($partDir -and (Test-Path -LiteralPath $partDir)) {
                Remove-Item -LiteralPath $partDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Warn 'parallel download failed; falling back to a single stream'
    Get-RemoteFile -Uri $Uri -OutFile $OutFile -Label $Label -FallbackUri $FallbackUri -Sha256 $Sha256
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Expand-ArchiveFlat {
    param(
        [string]$Zip,
        [string]$Dest
    )

    $tmp = "$Dest.__extract"
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
    if (Test-Path -LiteralPath $Dest) {
        Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $tmp)

    $items = @(Get-ChildItem -LiteralPath $tmp -Force)
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        Move-Item -LiteralPath $items[0].FullName -Destination $Dest
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
    else {
        Move-Item -LiteralPath $tmp -Destination $Dest
    }
}

function Ensure-ZipTool {
    param(
        [string]$Name,
        [string]$Url,
        [string]$ZipFile,
        [string]$Folder,
        [string]$ExeName,
        [string]$FallbackUrl = '',
        [string]$Sha256 = ''
    )

    $dest = Join-Path $ToolsDir $Folder
    $exe = Find-File $dest $ExeName
    if ($exe -and -not $Force) {
        Write-Host "    already installed: $exe"
        return @{ Dest = $dest; Exe = $exe }
    }

    $zip = Join-Path $DownloadsDir $ZipFile
    if ($Url -like 'https://github.com/*') {
        Get-GitHubAsset -Uri $Url -OutFile $zip -Label $Name -Sha256 $Sha256
    }
    else {
        Get-RemoteFile -Uri $Url -OutFile $zip -Label $Name -FallbackUri $FallbackUrl
    }
    Expand-ArchiveFlat -Zip $zip -Dest $dest
    $exe = Find-File $dest $ExeName
    if (-not $exe) {
        throw "$ExeName was not found after extracting $Name"
    }
    return @{ Dest = $dest; Exe = $exe }
}

function Install-Jdk {
    Write-Step 'Temurin JDK 25'
    $jdk = Ensure-ZipTool -Name 'Temurin JDK 25' -Url $JdkUrl -ZipFile 'jdk25.zip' -Folder 'jdk25' -ExeName 'java.exe' -FallbackUrl $JdkFallbackUrl
    $script:JavaHome = Split-Path -Parent (Split-Path -Parent $jdk.Exe)
    Add-LabPath (Join-Path $script:JavaHome 'bin')
    $env:JAVA_HOME = $script:JavaHome
    $env:PATH = (Join-Path $script:JavaHome 'bin') + ';' + $env:PATH
    $version = '25.0.5'
    Write-Ok "JAVA_HOME=$script:JavaHome"
    Add-Report 'Temurin JDK 25' 'ok' $script:JavaHome $version
}

function Invoke-ToolBlock {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
    }
    catch {
        Add-Report $Name 'failed' '' '' $_.Exception.Message
        Write-Err "$Name failed: $($_.Exception.Message)"
    }
}

function Install-CoreTools {
    Invoke-ToolBlock 'Ghidra' {
        Write-Step 'Ghidra'
        $g = Ensure-ZipTool -Name 'Ghidra 12.2' -Url $GhidraUrl -ZipFile 'ghidra.zip' -Folder 'ghidra' -ExeName 'ghidraRun.bat' -Sha256 '2c2cd776db3c1f6a097ba418922378ac3649cadd5e844a6f5f088ae628a7be67'
        Add-Report 'Ghidra' 'ok' $g.Exe '12.2'
        Write-Ok $g.Exe
    }

    Invoke-ToolBlock 'radare2' {
        Write-Step 'radare2'
        $r2 = Ensure-ZipTool -Name 'radare2 6.2.6' -Url $Radare2Url -ZipFile 'radare2.zip' -Folder 'radare2' -ExeName 'radare2.exe'
        Add-LabPath (Split-Path -Parent $r2.Exe)
        $env:PATH = (Split-Path -Parent $r2.Exe) + ';' + $env:PATH
        $ver = (& $r2.Exe -v 2>&1 | Select-Object -First 1)
        Add-Report 'radare2' 'ok' $r2.Exe $ver
        Write-Ok $r2.Exe
    }

    Invoke-ToolBlock 'Cutter' {
        Write-Step 'Cutter'
        $c = Ensure-ZipTool -Name 'Cutter 2.5.0' -Url $CutterUrl -ZipFile 'cutter.zip' -Folder 'cutter' -ExeName 'cutter.exe'
        Add-Report 'Cutter' 'ok' $c.Exe '2.5.0'
        Write-Ok $c.Exe
    }

    Invoke-ToolBlock 'x64dbg' {
        Write-Step 'x64dbg'
        $x = Ensure-ZipTool -Name 'x64dbg snapshot 2026-05-27' -Url $X64dbgUrl -ZipFile 'x64dbg.zip' -Folder 'x64dbg' -ExeName 'x64dbg.exe'
        Add-Report 'x64dbg' 'ok' $x.Exe '2026-05-27'
        Write-Ok $x.Exe
    }

    Invoke-ToolBlock 'ImHex' {
        Write-Step 'ImHex'
        $i = Ensure-ZipTool -Name 'ImHex 1.38.1' -Url $ImHexUrl -ZipFile 'imhex.zip' -Folder 'imhex' -ExeName 'imhex.exe'
        Add-Report 'ImHex' 'ok' $i.Exe '1.38.1'
        Write-Ok $i.Exe
    }

    Invoke-ToolBlock 'jadx' {
        Write-Step 'jadx'
        $j = Ensure-ZipTool -Name 'jadx 1.5.6 (with JRE)' -Url $JadxUrl -ZipFile 'jadx.zip' -Folder 'jadx' -ExeName 'jadx-gui*.exe'
        Add-LabPath (Split-Path -Parent $j.Exe)
        $env:PATH = (Split-Path -Parent $j.Exe) + ';' + $env:PATH
        Add-Report 'jadx' 'ok' $j.Exe '1.5.6'
        Write-Ok $j.Exe
    }

    Invoke-ToolBlock 'ILSpy' {
        Write-Step 'ILSpy'
        $il = Ensure-ZipTool -Name 'ILSpy 11.2' -Url $ILSpyUrl -ZipFile 'ilspy.zip' -Folder 'ilspy' -ExeName 'ILSpy.exe'
        Add-Report 'ILSpy' 'ok' $il.Exe '11.2'
        Write-Ok $il.Exe
    }

    Invoke-ToolBlock 'dnSpyEx' {
        Write-Step 'dnSpyEx'
        $dn = Ensure-ZipTool -Name 'dnSpyEx 6.6.0' -Url $DnSpyUrl -ZipFile 'dnspy.zip' -Folder 'dnspy' -ExeName 'dnSpy.exe'
        Add-Report 'dnSpyEx' 'ok' $dn.Exe '6.6.0'
        Write-Ok $dn.Exe
    }
}

function Install-Apktool {
    Write-Step 'Apktool 3.0.3'
    if (-not $script:JavaHome) {
        throw 'Apktool requires the JDK, which is not available.'
    }

    $dir = Join-Path $ToolsDir 'apktool'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $jar = Join-Path $dir 'apktool.jar'
    if (-not (Test-Path -LiteralPath $jar) -or $Force) {
        $download = Join-Path $DownloadsDir 'apktool.jar'
        Get-GitHubAsset -Uri $ApktoolUrl -OutFile $download -Label 'Apktool 3.0.3'
        Copy-Item -LiteralPath $download -Destination $jar -Force
    }

    $bat = @'
@echo off
setlocal
if defined JAVA_HOME (
  "%JAVA_HOME%\bin\java.exe" -jar "%~dp0apktool.jar" %*
) else (
  java -jar "%~dp0apktool.jar" %*
)
'@
    Set-Content -LiteralPath (Join-Path $dir 'apktool.bat') -Value $bat -Encoding ASCII
    Add-LabPath $dir
    $env:PATH = $dir + ';' + $env:PATH
    Add-Report 'Apktool' 'ok' (Join-Path $dir 'apktool.bat') '3.0.3'
    Write-Ok (Join-Path $dir 'apktool.bat')
}

function Install-Kaitai {
    Write-Step 'Kaitai Struct Compiler 0.11'
    if (-not $script:JavaHome) {
        throw 'Kaitai Struct Compiler requires the JDK, which is not available.'
    }

    $k = Ensure-ZipTool -Name 'Kaitai Struct Compiler 0.11' -Url $KaitaiUrl -ZipFile 'kaitai.zip' -Folder 'kaitai' -ExeName 'kaitai-struct-compiler.bat'
    Add-LabPath (Split-Path -Parent $k.Exe)
    $env:PATH = (Split-Path -Parent $k.Exe) + ';' + $env:PATH
    Add-Report 'Kaitai Struct Compiler' 'ok' $k.Exe '0.11'
    Write-Ok $k.Exe
}

function Install-PythonTool {
    Write-Step 'Python 3.12 and Python packages'
    $pyDir = Join-Path $ToolsDir 'python'
    $py = Join-Path $pyDir 'python.exe'

    if (-not (Test-Path -LiteralPath $py) -or $Force) {
        $installer = Join-Path $DownloadsDir 'python-3.12.10-amd64.exe'
        Get-RemoteFile -Uri $PythonUrl -OutFile $installer -Label 'Python 3.12.10' -FallbackUri $PythonFallbackUrl
        $arguments = "/quiet InstallAllUsers=0 TargetDir=`"$pyDir`" PrependPath=0 Shortcuts=0 Include_launcher=0 Include_test=0 Include_doc=0 Include_pip=1 Include_tcltk=1"
        $proc = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "Python installer exited with code $($proc.ExitCode)"
        }
    }

    if (-not (Test-Path -LiteralPath $py)) {
        throw 'python.exe was not found after installation.'
    }

    Add-LabPath $pyDir
    Add-LabPath (Join-Path $pyDir 'Scripts')
    $env:PATH = $pyDir + ';' + (Join-Path $pyDir 'Scripts') + ';' + $env:PATH

    & $py -m pip install --upgrade pip --disable-pip-version-check --index-url $PipIndex
    if ($LASTEXITCODE -ne 0) {
        throw 'pip self-upgrade failed.'
    }

    $packages = @(
        'mitmproxy',
        'androguard',
        'frida-tools',
        'construct',
        'blackboxprotobuf',
        'scapy',
        'kaitaistruct',
        'lief'
    )
    & $py -m pip install --disable-pip-version-check --index-url $PipIndex @packages
    if ($LASTEXITCODE -ne 0) {
        throw 'pip package installation failed.'
    }

    if ($IncludeAngr) {
        Write-Host '    installing optional angr ...'
        & $py -m pip install --disable-pip-version-check --index-url $PipIndex angr
        if ($LASTEXITCODE -ne 0) {
            Write-Warn 'angr installation failed; continuing without it.'
        }
    }

    $ver = (& $py --version 2>&1 | Select-Object -First 1)
    Add-Report 'Python 3.12 + packages' 'ok' $py $ver
    Write-Ok $ver
}

function Install-NodeTool {
    Write-Step 'Node.js 22 and npm tools'
    $nodeRoot = Join-Path $ToolsDir 'node'
    $node = Find-File $nodeRoot 'node.exe'

    if (-not $node -or $Force) {
        $zip = Join-Path $DownloadsDir 'node.zip'
        Get-RemoteFile -Uri $NodeUrl -OutFile $zip -Label 'Node.js 22.14.0' -FallbackUri $NodeFallbackUrl
        Expand-ArchiveFlat -Zip $zip -Dest $nodeRoot
        $node = Find-File $nodeRoot 'node.exe'
    }

    if (-not $node) {
        throw 'node.exe was not found after extraction.'
    }

    $nodeDir = Split-Path -Parent $node
    $npm = Join-Path $nodeDir 'npm.cmd'
    if (-not (Test-Path -LiteralPath $npm)) {
        throw 'npm.cmd was not found next to node.exe.'
    }

    Add-LabPath $nodeDir
    $env:PATH = $nodeDir + ';' + $env:PATH

    $globalDir = Join-Path $nodeDir 'global'
    & $npm install -g --prefix $globalDir asar webcrack --no-audit --no-fund --registry $NpmRegistry
    if ($LASTEXITCODE -ne 0) {
        throw 'npm global package installation failed.'
    }

    Add-LabPath $globalDir
    $env:PATH = $globalDir + ';' + $env:PATH
    $ver = (& $node --version 2>&1 | Select-Object -First 1)
    Add-Report 'Node.js + asar/webcrack' 'ok' $node $ver
    Write-Ok $ver
}

function New-EnvFile {
    $pathValue = (@($script:ExtraPath | Select-Object -Unique) -join ';')
    $content = @(
        '# Generated by Deploy-RELab.ps1',
        "`$env:RELAB_HOME = '$LabRoot'",
        "`$env:JAVA_HOME = '$script:JavaHome'",
        "`$env:PATH = '$pathValue;' + `$env:PATH"
    )
    Set-Content -LiteralPath $EnvFile -Value $content -Encoding ASCII
}

function Add-Entry {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Kind,
        [string]$Args = ''
    )
    if (-not $Path) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $script:Entries.Add([pscustomobject]@{
        name = $Name
        path = $Path
        kind = $Kind
        args = $Args
    })
}

function New-Manifest {
    $script:Entries.Clear()

    Add-Entry 'Ghidra' (Find-File (Join-Path $ToolsDir 'ghidra') 'ghidraRun.bat') 'gui'
    Add-Entry 'Cutter' (Find-File (Join-Path $ToolsDir 'cutter') 'cutter.exe') 'gui'
    Add-Entry 'x64dbg' (Find-File (Join-Path $ToolsDir 'x64dbg') 'x64dbg.exe') 'gui'
    Add-Entry 'ImHex' (Find-File (Join-Path $ToolsDir 'imhex') 'imhex.exe') 'gui'
    Add-Entry 'jadx' (Find-File (Join-Path $ToolsDir 'jadx') 'jadx-gui*.exe') 'gui'
    Add-Entry 'ILSpy' (Find-File (Join-Path $ToolsDir 'ilspy') 'ILSpy.exe') 'gui'
    Add-Entry 'dnSpyEx' (Find-File (Join-Path $ToolsDir 'dnspy') 'dnSpy.exe') 'gui'
    Add-Entry 'radare2' (Find-File (Join-Path $ToolsDir 'radare2') 'radare2.exe') 'shell'
    Add-Entry 'Apktool' (Join-Path $ToolsDir 'apktool\apktool.bat') 'shell'
    Add-Entry 'Kaitai Struct' (Find-File (Join-Path $ToolsDir 'kaitai') 'kaitai-struct-compiler.bat') 'shell'
    Add-Entry 'Python' (Join-Path $ToolsDir 'python\python.exe') 'shell'
    Add-Entry 'mitmweb' (Join-Path $ToolsDir 'python\Scripts\mitmweb.exe') 'gui' '--web-port 8081'
    Add-Entry 'Node.js' (Join-Path $ToolsDir 'node\node.exe') 'shell'
    Add-Entry 'asar' (Join-Path $ToolsDir 'node\global\asar.cmd') 'shell'
    Add-Entry 'webcrack' (Join-Path $ToolsDir 'node\global\webcrack.cmd') 'shell'

    $json = ConvertTo-Json -InputObject $script:Entries.ToArray() -Depth 4
    Set-Content -LiteralPath $ManifestFile -Value $json -Encoding UTF8
}

function Show-Plan {
    $plan = @(
        [pscustomobject]@{ Name = 'Temurin JDK 25'; Url = $JdkUrl },
        [pscustomobject]@{ Name = 'Ghidra 12.2'; Url = $GhidraUrl },
        [pscustomobject]@{ Name = 'radare2 6.2.6'; Url = $Radare2Url },
        [pscustomobject]@{ Name = 'Cutter 2.5.0'; Url = $CutterUrl },
        [pscustomobject]@{ Name = 'x64dbg'; Url = $X64dbgUrl },
        [pscustomobject]@{ Name = 'ImHex 1.38.1'; Url = $ImHexUrl },
        [pscustomobject]@{ Name = 'jadx 1.5.6'; Url = $JadxUrl },
        [pscustomobject]@{ Name = 'Apktool 3.0.3'; Url = $ApktoolUrl },
        [pscustomobject]@{ Name = 'ILSpy 11.2'; Url = $ILSpyUrl },
        [pscustomobject]@{ Name = 'dnSpyEx 6.6.0'; Url = $DnSpyUrl },
        [pscustomobject]@{ Name = 'Kaitai 0.11'; Url = $KaitaiUrl }
    )
    if (-not $SkipPython) {
        $plan += [pscustomobject]@{ Name = 'Python 3.12.10'; Url = $PythonUrl }
    }
    if (-not $SkipNode) {
        $plan += [pscustomobject]@{ Name = 'Node.js 22.14.0'; Url = $NodeUrl }
    }
    $plan | Format-Table -AutoSize -Wrap
    Write-Host ''
    Write-Host 'Approximate download size: 1.2 GB (Python/Node add about 250 MB).'
    Write-Host "Install target: $ToolsDir"
}

function Show-Summary {
    Write-Host ''
    Write-Host '================ INSTALL SUMMARY ================' -ForegroundColor Cyan
    $script:Report | Format-Table -AutoSize name, status, version, path | Out-String -Width 220 | Write-Host
    $ok = @($script:Report | Where-Object { $_.status -eq 'ok' }).Count
    $failed = @($script:Report | Where-Object { $_.status -eq 'failed' }).Count
    $skipped = @($script:Report | Where-Object { $_.status -eq 'skipped' }).Count
    Write-Host ("Installed: {0}  Failed: {1}  Skipped: {2}" -f $ok, $failed, $skipped)
    Write-Host "Launcher: $(Join-Path $LabRoot 'Start-RELab.cmd')"
    Write-Host '=================================================' -ForegroundColor Cyan
    if ($failed -gt 0) { return 1 }
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '  ____  _____    _         _     ' -ForegroundColor Cyan
Write-Host ' |  _ \| ____|  / \   __ _| |__  ' -ForegroundColor Cyan
Write-Host ' | |_) |  _|   / _ \ / _` | ''_ \ ' -ForegroundColor Cyan
Write-Host ' |  _ <| |___ / ___ \ (_| | |_) |' -ForegroundColor Cyan
Write-Host ' |_| \_\_____/_/   \_\__,_|_.__/ ' -ForegroundColor Cyan
Write-Host ' Portable reverse-engineering lab for Windows' -ForegroundColor DarkGray
Write-Host ''

if ($DryRun) {
    Show-Plan
    exit 0
}

New-Item -ItemType Directory -Path $LabRoot -Force | Out-Null
New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
New-Item -ItemType Directory -Path $DownloadsDir -Force | Out-Null

try {
    Start-Transcript -LiteralPath $LogFile -Append | Out-Null
} catch { }

try {
    $driveName = (Get-Item -LiteralPath $LabRoot).PSDrive.Name
    $free = (Get-PSDrive -Name $driveName).Free
    if ($free -lt 6GB) {
        throw "Not enough free space on ${driveName}: $([math]::Round($free / 1GB, 1)) GB available, 6 GB required."
    }
    Write-Host ("Free space on {0}: {1:N1} GB" -f $driveName, ($free / 1GB))

    $jdkOk = $false
    try {
        Install-Jdk
        $jdkOk = $true
    }
    catch {
        Add-Report 'Temurin JDK 25' 'failed' '' '' $_.Exception.Message
        Write-Err $_.Exception.Message
    }

    try {
        Install-CoreTools
    }
    catch {
        Add-Report 'Core tools' 'failed' '' '' $_.Exception.Message
        Write-Err $_.Exception.Message
    }

    if ($jdkOk) {
        try { Install-Apktool }
        catch {
            Add-Report 'Apktool' 'failed' '' '' $_.Exception.Message
            Write-Err $_.Exception.Message
        }
        try { Install-Kaitai }
        catch {
            Add-Report 'Kaitai Struct Compiler' 'failed' '' '' $_.Exception.Message
            Write-Err $_.Exception.Message
        }
    }
    else {
        Add-Report 'Apktool' 'skipped' '' '' 'JDK unavailable'
        Add-Report 'Kaitai Struct Compiler' 'skipped' '' '' 'JDK unavailable'
        Write-Warn 'Skipping Java-based tools because the JDK install failed.'
    }

    if (-not $SkipPython) {
        try { Install-PythonTool }
        catch {
            Add-Report 'Python 3.12 + packages' 'failed' '' '' $_.Exception.Message
            Write-Err $_.Exception.Message
        }
    }
    else {
        Add-Report 'Python 3.12 + packages' 'skipped' '' '' 'SkipPython'
    }

    if (-not $SkipNode) {
        try { Install-NodeTool }
        catch {
            Add-Report 'Node.js + asar/webcrack' 'failed' '' '' $_.Exception.Message
            Write-Err $_.Exception.Message
        }
    }
    else {
        Add-Report 'Node.js + asar/webcrack' 'skipped' '' '' 'SkipNode'
    }

    New-EnvFile
    New-Manifest

    $reportJson = ConvertTo-Json -InputObject $script:Report.ToArray() -Depth 4
    Set-Content -LiteralPath $ReportFile -Value $reportJson -Encoding UTF8

    $verify = Join-Path $LabRoot 'Verify-RELab.ps1'
    if (Test-Path -LiteralPath $verify) {
        try { & $verify | Out-Host } catch { Write-Warn "Verification failed: $($_.Exception.Message)" }
    }

    $exitCode = Show-Summary
}
catch {
    Write-Err $_.Exception.Message
    Add-Report 'Deployment' 'failed' '' '' $_.Exception.Message
    $exitCode = 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}

Write-Host ''
Write-Host 'Done. See deploy.log and install-report.json for details.' -ForegroundColor DarkGray
exit $exitCode
