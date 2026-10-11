# 跨项目接续协议 · 工作记忆同步（本机工作记忆 -> 项目 docs\项目记忆.md）
# 来源：本机 workspaceStorage\<工作区>\GitHub.copilot-chat\memory-tool\memories\repo\*.md
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File tools/continuity/sync-memory.ps1
#       也可显式指定项目根：... -ProjectPath <项目根目录>
#       本机记忆为空且镜像已存在时默认跳过（防稀疏记忆覆盖完整镜像），-Force 强制写入。
# 说明：本脚本含中文，必须以 UTF-8 with BOM 保存（Windows PowerShell 5.1 按 GBK 读无 BOM 会报语法错误）。

param(
    [string]$ProjectPath = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# 项目根：优先 -ProjectPath；默认取脚本位置（tools\continuity）的上两级（可从任意目录运行）
if ($ProjectPath) {
    if (-not (Test-Path $ProjectPath)) {
        Write-Host "[记忆同步] 错误：-ProjectPath 不存在：$ProjectPath"
        exit 2
    }
    $projectRoot = (Resolve-Path $ProjectPath).Path
} else {
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$projectName = Split-Path $projectRoot -Leaf
$outFile = Join-Path $projectRoot 'docs\项目记忆.md'
$slug = $projectName.ToLower() -replace '\.', '-'

$storage = Join-Path $env:APPDATA 'Code\User\workspaceStorage'
if (-not (Test-Path $storage)) {
    Write-Host '[记忆同步] 跳过：未找到 workspaceStorage'
    exit 0
}

# 定位本项目对应的记忆目录：
#   ① 单文件夹工作区（workspace.json 无 "folders" 字段）且包含本项目 → 该目录全部 *.md；
#   ② 无单文件夹匹配时退到多根工作区（含 "folders"）→ 仅收文件名含项目 slug 的文件，防混入其他项目记忆。
$exact = @(); $multi = @()
Get-ChildItem $storage -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $wj = Join-Path $_.FullName 'workspace.json'
    if (Test-Path $wj) {
        try {
            $t = [IO.File]::ReadAllText($wj, [Text.Encoding]::UTF8)
            $decoded = [uri]::UnescapeDataString($t)
            if ($decoded -like "*$projectName*") {
                $memDir = Join-Path $_.FullName 'GitHub.copilot-chat\memory-tool\memories\repo'
                if (Test-Path $memDir) {
                    if ($t -like '*"folders"*') { $multi += $memDir } else { $exact += $memDir }
                }
            }
        } catch { }
    }
}
$useSlugFilter = $false
$dirs = @()
if ($exact.Count -gt 0) {
    $dirs = $exact
} elseif ($multi.Count -gt 0) {
    $dirs = $multi
    $useSlugFilter = $true
}

$files = @()
foreach ($d in $dirs) {
    Get-ChildItem $d -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
        if ($useSlugFilter) {
            $base = ([IO.Path]::GetFileNameWithoutExtension($_.Name)).ToLower()
            if (-not (($base -like "*$slug*") -or ($slug -like "*$base*"))) { return }
        }
        $files += $_
    }
}

# 去重：同名文件保留最近修改的一份；输出按文件名排序
$files = @($files | Sort-Object LastWriteTime -Descending | Group-Object Name | ForEach-Object { $_.Group[0] } | Sort-Object Name)

if ($files.Count -eq 0 -and -not $Force -and (Test-Path $outFile)) {
    $existing = [IO.File]::ReadAllText($outFile, [Text.Encoding]::UTF8)
    if ($existing.Trim().Length -gt 0) {
        Write-Host '[记忆同步] 跳过：本机工作记忆为空，且仓库镜像已存在（防稀疏记忆覆盖完整镜像）。'
        Write-Host '          先把 docs\项目记忆.md 内容并入本机记忆再同步；确要清空镜像请加 -Force。'
        exit 0
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# $projectName · 项目记忆（本机工作记忆同步）")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> 本文由 `tools/continuity/sync-memory.ps1` 自动同步（来源：本机 Copilot 工作记忆）。')
[void]$sb.AppendLine("> 同步时间：" + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
[void]$sb.AppendLine('')

if ($files.Count -eq 0) {
    [void]$sb.AppendLine('（本机工作记忆为空——尚无 repo 记忆文件。）')
} else {
    foreach ($f in $files) {
        [void]$sb.AppendLine("## $($f.Name)")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine([IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8))
        [void]$sb.AppendLine('')
    }
}

$dir = Split-Path $outFile
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
[IO.File]::WriteAllText($outFile, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
Write-Host "[记忆同步] 已同步 $($files.Count) 个记忆文件 -> docs\项目记忆.md"
