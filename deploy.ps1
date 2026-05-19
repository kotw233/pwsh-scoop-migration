#
# deploy.ps1 - 一键部署 PowerShell 环境
#
# 用法:
#   .\deploy.ps1              # 完整部署
#   .\deploy.ps1 -SkipApps   # 跳过软件安装
#   .\deploy.ps1 -Sync       # 同步最新配置
#

param(
    [switch]$SkipApps,
    [switch]$Sync
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

# 自动检测文档目录（兼容重定向到 D 盘的情况）
$DocPath = [Environment]::GetFolderPath('MyDocuments')
$TargetDir = Join-Path $DocPath "PowerShell"

# ========== 工具函数 ==========

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  → $Message" -ForegroundColor DarkGray
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# ========== 核心函数 ==========

function Ensure-Scoop {
    if (Test-CommandExists "scoop") {
        Write-Success "Scoop 已安装"
        return
    }

    Write-Step "安装 Scoop"
    
    # 设置代理（永久生效）
    Write-Info "设置代理: http://127.0.0.1:10809"
    scoop config proxy http://127.0.0.1:10809
    
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    irm get.scoop.sh | iex
    scoop config aria2-enabled true
    Write-Success "Scoop 安装完成"
}

function Restore-Buckets {
    Write-Step "恢复 Buckets"
    $bucketsFile = Join-Path $ScriptDir "buckets.txt"

    if (-not (Test-Path $bucketsFile)) {
        Write-Info "未找到 buckets.txt，跳过"
        return
    }

    $requiredBuckets = Get-Content $bucketsFile | Where-Object { $_.Trim() -ne "" }
    $currentBuckets = scoop bucket list 2>$null | ForEach-Object { $_.Name }

    foreach ($bucket in $requiredBuckets) {
        if ($currentBuckets -notcontains $bucket) {
            Write-Info "添加 bucket: $bucket"
            scoop bucket add $bucket
        }
    }
}

function Restore-Apps {
    Write-Step "恢复已安装应用"
    $appsFile = Join-Path $ScriptDir "installed_apps.json"

    if (-not (Test-Path $appsFile)) {
        Write-Info "未找到 installed_apps.json，跳过"
        return
    }

    # 确保代理已配置
    $proxy = scoop config proxy 2>$null
    if (-not $proxy) {
        Write-Info "设置代理: http://127.0.0.1:10809"
        scoop config proxy http://127.0.0.1:10809
    }

    $data = Get-Content $appsFile -Raw | ConvertFrom-Json
    $apps = $data.apps
    $total = $apps.Count
    $current = 0

    foreach ($app in $apps) {
        $current++
            $installed = scoop list $app.name 2>$null | Where-Object { $_.Name -eq $app.Name }

        if (-not $installed) {
            Write-Info "($current/$total) 安装: $($app.name)"
            scoop install $app.name 2>$null
        }
    }
}

function Deploy-Profile {
    Write-Step "部署 PowerShell Profile"

    # 确保目标目录存在
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # 备份旧配置
    $targetProfile = Join-Path $TargetDir "Microsoft.PowerShell_profile.ps1"
    if (Test-Path $targetProfile) {
        $backup = "$targetProfile.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $targetProfile $backup
        Write-Info "已备份旧配置到: $backup"
    }

    # 复制 profile
    Copy-Item (Join-Path $ScriptDir "Microsoft.PowerShell_profile.ps1") $targetProfile -Force
    Write-Success "Profile 已部署"

    # 复制 _scripts → _scripts
    $scriptsSource = Join-Path $ScriptDir "_scripts"
    $scriptsTarget = Join-Path $TargetDir "_scripts"
    if (Test-Path $scriptsSource) {
        if (Test-Path $scriptsTarget) {
            Remove-Item $scriptsTarget -Recurse -Force
        }
        Copy-Item $scriptsSource $scriptsTarget -Recurse -Force
        Write-Success "Scripts 目录已部署"
    }

    # 复制 _modules → _modules
    $modulesSource = Join-Path $ScriptDir "_modules"
    $modulesTarget = Join-Path $TargetDir "_modules"
    if (Test-Path $modulesSource) {
        if (Test-Path $modulesTarget) {
            Remove-Item $modulesTarget -Recurse -Force
        }
        Copy-Item $modulesSource $modulesTarget -Recurse -Force
        Write-Success "Modules 目录已部署"
    }

    # 部署 starship 主题（使用官方 preset）
    if (Test-CommandExists "starship") {
        Write-Info "应用 starship 主题: pure-preset"
        starship preset pure-preset -o "$env:USERPROFILE\.config\starship.toml" 2>$null
        Write-Success "Starship 主题已部署"
    }
}

# ========== 同步配置 ==========

function Sync-Config {
    Write-Step "同步最新配置"
    git -C $ScriptDir pull 2>$null
    Deploy-Profile
    Write-Success "同步完成，请重启 PowerShell 生效"
}

# ========== 主流程 ==========

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  PowerShell 工作环境部署工具" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host "目标: $TargetDir" -ForegroundColor DarkGray

if ($Sync) {
    Sync-Config
    return
}

try {
    if (-not $SkipApps) {
        Ensure-Scoop
        Restore-Buckets
        Restore-Apps
    }

    Deploy-Profile

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  ✅ 部署完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`n请重启 PowerShell 使配置生效。" -ForegroundColor Yellow
    
    # 提示需要手动配置的环境变量
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  📋 新电脑需要手动配置" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`n以下环境变量需要在 PowerShell 中设置一次（仅当前用户）：" -ForegroundColor DarkGray
    
    $envVars = @(
        @{ Name = "APPOBFUSC_TOOL"; Value = "D:\SecTools\AppTools\apphide\appinfo\appinfo.py"; Desc = "APK 混淆检测工具路径" },
        @{ Name = "EMULATOR_PATH"; Value = "D:\Soft\leidian\LDPlayer9\dnplayer.exe"; Desc = "模拟器路径（用于自动化测试）" }
    )
    
    foreach ($var in $envVars) {
        Write-Host "`n  $($var.Desc)" -ForegroundColor White
        Write-Host "  `$Env:$($var.Name) = '$($var.Value)'" -ForegroundColor Green
    }
    
    Write-Host "`n设置后永久保存（重启生效）：" -ForegroundColor DarkGray
    Write-Host "  [Environment]::SetEnvironmentVariable('变量名', '值', 'User')" -ForegroundColor Gray
}
catch {
    Write-Host "`n❌ 部署失败: $_" -ForegroundColor Red
    exit 1
}
