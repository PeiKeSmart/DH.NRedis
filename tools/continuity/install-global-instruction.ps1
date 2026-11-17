#Requires -Version 5.1
<#
.SYNOPSIS
  一键安装「用户级接续指令（按技术栈拆分版）」到本机 VS Code。
.DESCRIPTION
  把 templates\ 下的 5 个拆分指令逐个安装/更新到 %APPDATA%\Code\User\prompts\：
    跨项目接续协议 / Rust项目规范 / 服务端与数据规范 / 前端规范 / Zig项目规范
  幂等：缺失→安装、过旧→更新、一致→不动、比本机旧→跳过（版本守卫）。
  不再安装旧版 用户级指令.instructions.md（它只作索引/兼容存根）。
  供“打开项目自检”任务（.vscode/tasks.json）与 AI 接续自检共用。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/continuity/install-global-instruction.ps1
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
$srcDir = Join-Path $PSScriptRoot 'templates'
$names = @('跨项目接续协议', 'Rust项目规范', '服务端与数据规范', '前端规范', 'Zig项目规范')

if (-not (Test-Path $srcDir)) {
    Write-Host "未找到模板目录：$srcDir"
    exit 2
}

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "已创建目录：$targetDir"
}

function Get-FileVersion([string]$path) {
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $ms = [regex]::Matches($text, '版本：([0-9]+(?:\.[0-9]+)*)')
    if ($ms.Count -eq 0) { return '' }
    return $ms[$ms.Count - 1].Groups[1].Value
}

function Test-VersionNewer([string]$a, [string]$b) {
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

$installed = 0
$skipped = 0
$missing = 0

foreach ($n in $names) {
    $src = Join-Path $srcDir "$n.instructions.md"
    if (-not (Test-Path $src)) {
        Write-Host "MISSING：模板缺失 $src"
        $missing++
        continue
    }

    $dst = Join-Path $targetDir "$n.instructions.md"
    $srcHash = (Get-FileHash -Path $src -Algorithm SHA256).Hash
    $srcVer = Get-FileVersion $src

    if (Test-Path $dst) {
        $dstHash = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
        if ($srcHash -eq $dstHash) {
            $skipped++
            continue
        }
        $dstVer = Get-FileVersion $dst
        if ($dstVer -and $srcVer -and -not (Test-VersionNewer $srcVer $dstVer)) {
            Write-Host "SKIP：$n 本机版本较新（$dstVer >= $srcVer），保留本机副本"
            $skipped++
            continue
        }
    }

    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "INSTALLED：$n -> $dst（版本 $srcVer）"
    $installed++
}

if ($missing -gt 0) {
    Write-Host "ERROR：有 $missing 个模板缺失，安装未完成" -ForegroundColor Red
    exit 2
}

Write-Host "OK：拆分版用户级指令已就绪（安装 $installed，已一致/跳过 $skipped）"
exit 0
