<#
.SYNOPSIS
    AI 技能库 - 一键安装脚本（Windows）

.DESCRIPTION
    把本仓库 skills 目录下的技能安装到 WorkBuddy 的 skills 目录。

.PARAMETER All
    安装全部技能，不交互。

.PARAMETER Skill
    只安装指定名称的技能。

.PARAMETER Dest
    自定义目标目录。默认 <用户目录>\.workbuddy\skills

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1 -All

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1 -Skill web-access
#>

param(
    [switch]$All,
    [string]$Skill = "",
    [string]$Dest = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcDir = Join-Path $ScriptDir "skills"

if ($Dest -ne "") {
    $DestDir = $Dest
} elseif ($env:WORKBUDDY_SKILLS_DIR) {
    $DestDir = $env:WORKBUDDY_SKILLS_DIR
} else {
    $DestDir = Join-Path $env:USERPROFILE ".workbuddy\skills"
}

Write-Host "=============================================="
Write-Host " AI 技能库 - 安装"
Write-Host "=============================================="
Write-Host "源目录  : $SrcDir"
Write-Host "目标目录: $DestDir"
Write-Host ""

if (-not (Test-Path $SrcDir)) {
    Write-Host "错误: 找不到 skills 目录。" -ForegroundColor Red
    Write-Host "请确认在仓库根目录运行本脚本。" -ForegroundColor Red
    exit 1
}

$skills = @(Get-ChildItem -Path $SrcDir -Directory | Select-Object -ExpandProperty Name)

if ($skills.Count -eq 0) {
    Write-Host "错误: skills 目录为空。" -ForegroundColor Red
    exit 1
}

$targets = @()

if ($Skill -ne "") {
    if ($skills -contains $Skill) {
        $targets = @($Skill)
    } else {
        Write-Host "错误: 找不到技能「$Skill」。" -ForegroundColor Red
        Write-Host ("可用技能: " + ($skills -join ", ")) -ForegroundColor Red
        exit 1
    }
} elseif ($All) {
    $targets = $skills
} else {
    Write-Host "可用技能:"
    for ($i = 0; $i -lt $skills.Count; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $skills[$i])
    }
    Write-Host "  a) 全部安装"
    Write-Host ""

    $choice = Read-Host "请选择（输入序号，或 a 全部）"

    if ($choice -eq "a" -or $choice -eq "A") {
        $targets = $skills
    } else {
        $num = 0
        if ([int]::TryParse($choice, [ref]$num)) {
            if ($num -ge 1 -and $num -le $skills.Count) {
                $targets = @($skills[$num - 1])
            }
        }
    }

    if ($targets.Count -eq 0) {
        Write-Host "无效选择，已退出。" -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
}

Write-Host ""
foreach ($s in $targets) {
    $target = Join-Path $DestDir $s
    if (Test-Path $target) {
        Write-Host "  已存在，将覆盖: $s"
        Remove-Item $target -Recurse -Force
    }
    Copy-Item -Path (Join-Path $SrcDir $s) -Destination $target -Recurse -Force
    Write-Host "  已安装: $s"
}

Write-Host ""
Write-Host "完成。请重启 WorkBuddy（或新开一个会话）以加载技能。" -ForegroundColor Green
Write-Host "首次使用前，请阅读对应技能目录下的 INSTALL.md。"
