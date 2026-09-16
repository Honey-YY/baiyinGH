<#
.SYNOPSIS
    web-access skill - 安装脚本（Windows）

.DESCRIPTION
    把本仓库（即技能本体）安装到 AI 客户端的 skills 目录。
    本仓库是「一个 skill 一个仓库」结构，脚本所在目录就是技能本体，
    安装过程即把技能本体复制到 skills 目录下的 web-access\。

.PARAMETER Dest
    自定义目标目录。默认 <用户目录>\.workbuddy\skills

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1 -Dest "D:\my-skills"
#>

param(
    [string]$Dest = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillName = "web-access"

if ($Dest -ne "") {
    $DestDir = $Dest
} elseif ($env:WORKBUDDY_SKILLS_DIR) {
    $DestDir = $env:WORKBUDDY_SKILLS_DIR
} else {
    $DestDir = Join-Path $env:USERPROFILE ".workbuddy\skills"
}

$Target = Join-Path $DestDir $SkillName

Write-Host "=============================================="
Write-Host " web-access skill - 安装"
Write-Host "=============================================="
Write-Host "技能源目录: $ScriptDir"
Write-Host "目标目录  : $DestDir"
Write-Host "安装后位置: $Target"
Write-Host ""

$SkillMd = Join-Path $ScriptDir "SKILL.md"
if (-not (Test-Path $SkillMd)) {
    Write-Host "错误: 在脚本所在目录找不到 SKILL.md。" -ForegroundColor Red
    Write-Host "请确认在 web-access 仓库根目录运行本脚本。" -ForegroundColor Red
    exit 1
}

# 防呆：目标目录不能位于仓库内部，否则复制会自我递归
if ($Target.StartsWith($ScriptDir + [IO.Path]::DirectorySeparatorChar)) {
    Write-Host "错误: 目标目录不能位于仓库内部。" -ForegroundColor Red
    exit 1
}

# 已经就是安装位置（例如直接 git clone 到了 skills 目录）
if (Test-Path $Target) {
    $srcReal = (Get-Item $ScriptDir).FullName.TrimEnd("\")
    $dstReal = (Get-Item $Target).FullName.TrimEnd("\")
    if ($srcReal -eq $dstReal) {
        Write-Host "本目录已经是技能的安装位置，无需复制。"
        Write-Host "请重启 AI 客户端（或新开一个会话）以加载技能。" -ForegroundColor Green
        exit 0
    }
    Write-Host "目标已存在，将覆盖: $Target"
    Remove-Item $Target -Recurse -Force
}

New-Item -ItemType Directory -Path $Target -Force | Out-Null
Copy-Item -Path (Join-Path $ScriptDir "*") -Destination $Target -Recurse -Force

# 去掉仓库管道文件：它们与技能运行无关，留着会污染技能目录
$plumbing = @(
    ".git", "dist", "tools",
    "install.sh", "install.ps1", "package.json",
    ".gitattributes", ".gitignore", "config.env"
)
foreach ($p in $plumbing) {
    $q = Join-Path $Target $p
    if (Test-Path $q) {
        Remove-Item $q -Recurse -Force
    }
}

Write-Host ""
Write-Host "安装完成: $Target" -ForegroundColor Green
Write-Host ""
Write-Host "完成。请重启 AI 客户端（或新开一个会话）以加载技能。"
Write-Host "首次使用前，请阅读 $Target\INSTALL.md。"
