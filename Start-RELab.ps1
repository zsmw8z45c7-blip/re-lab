#requires -Version 5.1
<#
.SYNOPSIS
    RE Lab 简体中文启动器。

.PARAMETER Tool
    按名称启动工具，例如 Ghidra、Cutter、jadx、Python。

.PARAMETER List
    列出已安装工具和中文说明。
#>
[CmdletBinding()]
param(
    [string]$Tool,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$LabRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $LabRoot 'env.ps1'
$ManifestFile = Join-Path $LabRoot 'lab-manifest.json'
$GuideFile = Join-Path $LabRoot '新手速查表.md'

if (Test-Path -LiteralPath $EnvFile) {
    . $EnvFile
}

if (-not (Test-Path -LiteralPath $ManifestFile)) {
    Write-Host 'RE Lab 还没有部署。' -ForegroundColor Red
    Write-Host "请先双击：$(Join-Path $LabRoot '1-一键部署.cmd')" -ForegroundColor Yellow
    exit 1
}

$raw = Get-Content -LiteralPath $ManifestFile -Raw
$tools = $raw | ConvertFrom-Json
if ($tools -isnot [System.Array]) {
    $tools = @($tools)
}

if ($tools.Count -eq 0) {
    Write-Host '没有找到已安装的工具，请先运行一键部署。' -ForegroundColor Red
    exit 1
}

$Descriptions = @{
    'Ghidra'         = '英文界面，功能最全；新手建议先用 Cutter'
    'Cutter'         = '简体中文界面，图形化逆向，新手推荐'
    'x64dbg'         = '动态调试 Windows 程序，查看寄存器、内存、断点'
    'ImHex'          = '十六进制查看器，适合分析未知文件格式'
    'jadx'           = '把安卓 APK 反编译成 Java 代码'
    'ILSpy'          = '把 .NET 程序反编译成 C# 代码'
    'dnSpyEx'        = '调试和修改 .NET 程序'
    'radare2'        = '命令行逆向工具，适合进阶用户'
    'Apktool'        = '解包 APK 的资源、Manifest、smali'
    'Kaitai Struct'  = '按格式描述解析二进制文件'
    'Python'         = 'Python 环境，已装 frida、mitmproxy 等'
    'mitmweb'        = '打开网页抓包界面（HTTP/HTTPS）'
    'Node.js'        = 'Node.js 环境'
    'asar'           = '解包 Electron 应用的 asar 包'
    'webcrack'       = '反混淆、解包前端 JS'
}

function Get-ToolDescription {
    param([string]$Name)
    if ($Descriptions.ContainsKey($Name)) {
        return $Descriptions[$Name]
    }
    return ''
}

function Launch-Tool {
    param($Item)

    if (-not (Test-Path -LiteralPath $Item.path)) {
        Write-Host "找不到文件：$($Item.path)" -ForegroundColor Red
        return
    }

    $description = Get-ToolDescription $Item.name

    if ($Item.kind -eq 'gui') {
        Write-Host "正在启动 $($Item.name) ..." -ForegroundColor Green
        if ($description) {
            Write-Host "  $description" -ForegroundColor DarkGray
        }
        $workDir = Split-Path -Parent $Item.path
        if ($Item.args) {
            Start-Process -FilePath $Item.path -ArgumentList $Item.args -WorkingDirectory $workDir
        }
        else {
            Start-Process -FilePath $Item.path -WorkingDirectory $workDir
        }
        Write-Host "已启动：$($Item.name)" -ForegroundColor Green
        return
    }

    $command = "& '$EnvFile'; Write-Host 'RE Lab：$($Item.name)' -ForegroundColor Cyan; Write-Host '$description' -ForegroundColor DarkGray; & '$($Item.path)'"
    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command) `
        -WorkingDirectory $LabRoot
    Write-Host "已打开命令行窗口：$($Item.name)" -ForegroundColor Green
}

if ($List) {
    $rows = for ($i = 0; $i -lt $tools.Count; $i++) {
        [pscustomobject]@{
            '编号' = $i + 1
            '工具' = $tools[$i].name
            '类型' = if ($tools[$i].kind -eq 'gui') { '图形界面' } else { '命令行' }
            '说明' = Get-ToolDescription $tools[$i].name
        }
    }
    $rows | Format-Table -AutoSize -Wrap
    exit 0
}

if ($Tool) {
    $match = $tools | Where-Object {
        $_.name -eq $Tool -or $_.name -like "*$Tool*"
    } | Select-Object -First 1

    if (-not $match) {
        Write-Host "没有找到工具：$Tool" -ForegroundColor Red
        Write-Host '可以用 -List 查看已安装工具。' -ForegroundColor Yellow
        exit 1
    }
    Launch-Tool $match
    exit 0
}

while ($true) {
    Clear-Host
    Write-Host ''
    Write-Host '  ==========================================' -ForegroundColor Cyan
    Write-Host '           RE Lab 简体中文控制台' -ForegroundColor Cyan
    Write-Host '  ==========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  新手建议：' -ForegroundColor Yellow
    Write-Host '    看 Windows 程序  →  Cutter（中文界面）'
    Write-Host '    看安卓 APK      →  jadx'
    Write-Host '    看 .NET 程序     →  ILSpy'
    Write-Host '    看未知文件       →  ImHex'
    Write-Host '    抓 HTTP 包       →  mitmweb'
    Write-Host ''
    for ($i = 0; $i -lt $tools.Count; $i++) {
        $kind = if ($tools[$i].kind -eq 'gui') { '图形界面' } else { '命令行' }
        Write-Host ("  {0,2}. {1}  [{2}]" -f ($i + 1), $tools[$i].name, $kind) -ForegroundColor White
        $description = Get-ToolDescription $tools[$i].name
        if ($description) {
            Write-Host ("      {0}" -f $description) -ForegroundColor DarkGray
        }
    }
    Write-Host ''
    Write-Host '   H. 打开中文速查表'
    Write-Host '   0. 退出'
    Write-Host ''
    $selection = Read-Host '请输入编号'

    if ($selection -eq '0') { break }

    if ($selection -match '^[Hh]$') {
        if (Test-Path -LiteralPath $GuideFile) {
            Start-Process -FilePath notepad.exe -ArgumentList $GuideFile
        }
        else {
            Write-Host '没有找到中文速查表。' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        continue
    }

    $index = 0
    if ([int]::TryParse($selection, [ref]$index) -and $index -ge 1 -and $index -le $tools.Count) {
        Launch-Tool $tools[$index - 1]
        Start-Sleep -Seconds 1
    }
    else {
        Write-Host '编号无效，请重新输入。' -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}
