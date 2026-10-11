#Requires -Version 5.1
<#
.SYNOPSIS
  一键安装「用户级接续指令」到本机 VS Code —— 本机所有项目自动获得接续协议与用户偏好。
.DESCRIPTION
  把 templates\用户级指令.instructions.md 安装/更新到 %APPDATA%\Code\User\prompts\（VS Code
  用户级指令目录）。幂等三态：缺失→安装、过旧→更新、一致→不动。
  供“打开项目自检”任务（.vscode/tasks.json）与 AI 接续自检共用；含版本守卫（旧仓库不会覆盖新副本）。
  若已启用 Settings Sync 且勾选 "Prompts and Instructions"，该文件会自动漫游到其他电脑。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/continuity/install-global-instruction.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/continuity/install-global-instruction.ps1 -Insiders
#>
param(
    [switch]$Insiders
)

$ErrorActionPreference = 'Stop'

$channel = 'Code'
if ($Insiders) { $channel = 'Code - Insiders' }

if (-not $env:APPDATA) {
    Write-Host '未找到 APPDATA 环境变量（仅支持 Windows / VS Code 桌面版）。'
    exit 2
}

$targetDir = Join-Path $env:APPDATA "$channel\User\prompts"
$source = Join-Path $PSScriptRoot 'templates\用户级指令.instructions.md'

if (-not (Test-Path $source)) {
    Write-Host "未找到模板文件：$source"
    Write-Host '请在已装备的仓库内运行本脚本（tools/continuity/templates/ 应含该模板）。'
    exit 2
}

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "已创建目录：$targetDir"
}

$dest = Join-Path $targetDir '跨项目接续协议.instructions.md'

function Get-FileVersion([string]$path) {
    if (-not (Test-Path $path)) { return '' }
    $text = [IO.File]::ReadAllText($path)
    $m = [regex]::Match($text, '版本：([0-9]+(?:\.[0-9]+)*)')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Test-VersionNewer([string]$a, [string]$b) {
    # $a 比 $b 新则返回 $true（分段数值比较）
    $pa = @(); if ($a) { $pa = $a.Split('.') | ForEach-Object { [int]$_ } }
    $pb = @(); if ($b) { $pb = $b.Split('.') | ForEach-Object { [int]$_ } }
    $n = [Math]::Max($pa.Count, $pb.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $x = 0; $y = 0
        if ($i -lt $pa.Count) { $x = $pa[$i] }
        if ($i -lt $pb.Count) { $y = $pb[$i] }
        if ($x -gt $y) { return $true }
        if ($x -lt $y) { return $false }
    }
    return $false
}

$srcVer = Get-FileVersion $source
$srcHash = (Get-FileHash -Path $source -Algorithm SHA256).Hash

if (-not (Test-Path $dest)) {
    Copy-Item -Path $source -Destination $dest -Force
    Write-Host "INSTALLED：已安装用户级指令 -> $dest（版本 $srcVer）"
    exit 0
}

$dstHash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash
if ($srcHash -eq $dstHash) {
    Write-Host "OK：已是最新（版本 $srcVer），无需操作"
    exit 0
}

$dstVer = Get-FileVersion $dest
try { $srcNewer = Test-VersionNewer $srcVer $dstVer } catch { $srcNewer = $true }
if (-not $srcNewer -and $srcVer -and $dstVer -and $srcVer -ne $dstVer) {
    Write-Host "SKIP：本仓库模板版本较旧（$srcVer < $dstVer），已保留本机较新副本；建议 git pull 更新本项目"
    exit 0
}

$oldText = if ($dstVer) { $dstVer } else { '无版本' }
Copy-Item -Path $source -Destination $dest -Force
Write-Host "UPDATED：已更新用户级指令 -> $dest（$oldText -> $srcVer）"
Write-Host '说明：本机所有项目在“新开的会话”中自动生效；漫游到其他电脑见 README“两条路”。'
