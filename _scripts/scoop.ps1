# _scripts/scoop.ps1

#   1、安装 Scoop 到 D:\Scoop，并恢复应用和 bucket
#   2、配置 Scoop 别名等

# 设置 Scoop 安装路径
# $SCOOP_PATH = "D:/Scoop"

function Test-ScoopInstalled {
    return (Get-Command scoop -ErrorAction SilentlyContinue) -ne $null
}

# function Install-Scoop {
#     param(
#         [string]$InstallPath = $SCOOP_PATH
#     )

#     Write-Host "📦 正在安装 Scoop 到: $InstallPath" -ForegroundColor Cyan

#     # 创建安装目录（如果不存在）
#     if (-not (Test-Path $InstallPath)) {
#         New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
#     }

#     # 设置环境变量
#     $env:SCOOP = $InstallPath

#     # 下载并安装 Scoop
#     irm get.scoop.sh | iex
# }

# function Restore-ScoopState {
#     param(
#         [string]$JsonFile = "installed_apps.json"
#     )

#     if (-not (Test-Path $JsonFile)) {
#         Write-Warning "⚠️ 未找到 '$JsonFile'，跳过 Scoop 应用恢复。"
#         return
#     }

#     Write-Host "🔄 正在导入 Scoop 状态..." -ForegroundColor Cyan

#     try {
#         # 检查 JSON 是否合法
#         $content = Get-Content $JsonFile -Raw -ErrorAction Stop
#         $json = ConvertFrom-Json $content -ErrorAction Stop

#         # 添加 buckets
#         if ($json.buckets) {
#             foreach ($bucket in $json.buckets) {
#                 Write-Host "📁 添加 bucket: $bucket" -ForegroundColor Green
#                 scoop bucket add $bucket
#             }
#         }

#         # 安装 apps
#         if ($json.apps) {
#             $apps = $json.apps.PSObject.Properties.Name
#             if ($apps.Count -gt 0) {
#                 Write-Host "🎁 安装应用程序: $($apps -join ', ')" -ForegroundColor Green
#                 scoop install $apps
#             }
#         }
#     } catch {
#         Write-Error "❌ 导入 Scoop 状态失败: $_"
#     }
# }

# # ========== 主流程开始 ==========

# # 设置 SCOOP 环境变量
# $env:SCOOP = $SCOOP_PATH

# # 如果 Scoop 没有安装，则安装它
# if (-not (Test-ScoopInstalled)) {
#     Install-Scoop -InstallPath $SCOOP_PATH
# } else {
#     Write-Host "✅ Scoop 已安装在: $env:SCOOP"
# }

# # 恢复 Scoop 状态（bucket + apps）
# $installJson = Join-Path $PSScriptRoot "../installed_apps.json"
# Restore-ScoopState -JsonFile $installJson

# Scoop别名创建脚本

if (Test-ScoopInstalled) {
    # 获取Scoop的shims目录
$shimsDir = if ($env:SCOOP) {
    Join-Path -Path $env:SCOOP -ChildPath "shims"
} else {
    Join-Path -Path (Split-Path -Path (Get-Command scoop).Path) -ChildPath "shims"
}

# 定义需要创建的别名映射
$aliases = @{
    "ls"  = "list"
    "i"   = "install"
    "rm"  = "uninstall"
    "u"   = "update"
    "s"   = "search"
    "v"   = "info"
    "cl"  = "cleanup"
    "c"   = "config"
    "ca"  = "cache"
    "b"   = "bucket"
    "bs"  = "bucket list"
    "ss"  = "status"
}

# 循环创建别名脚本
foreach ($alias in $aliases.Keys) {
    $scriptPath = Join-Path -Path $shimsDir -ChildPath "scoop-$alias.ps1"
    
    # 仅在文件不存在时创建并输出提示
    if (-not (Test-Path $scriptPath)) {
        "scoop $($aliases[$alias]) `$args" | Out-File -FilePath $scriptPath -Encoding UTF8
        Write-Host "✓ 已创建: scoop $alias → scoop $($aliases[$alias])" -ForegroundColor Green
    }
}
}


function aria2 {
    scoop config aria2-enabled true
}

function aria2-disabled {
    scoop config aria2-enabled false
}

#列出已安装python
function py-list {
    scoop list | Where-Object { $_ -match "(?i)python" }
}

# 添加列出已安装JDK
function jdk-list {
    scoop list | Where-Object { $_ -match "(?i)jdk|java" }
}

#切换java版本
function jdk-switch {
    param(
        [Parameter(Mandatory=$true)]
        [int]$version
    )
    
    # 确定包名（根据你实际安装的版本调整）
    $package = switch ($version) {
        8 { "openjdk8-redhat" }
        default { "openjdk$version" }
    }
    
    # 检查是否已安装
    if (-not (scoop list | Where-Object { $_.Name -eq $package })) {
        Write-Host "❌ $package 未安装，请先执行: scoop install $package" -ForegroundColor Red
        return
    }
    
    # 执行切换
    scoop reset $package
    $jdkPath = scoop prefix $package
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkPath, 'User')
    
    # 验证切换结果
    $javaVersion = (java -version 2>&1 | Select-String "version").Line
    Write-Host "✅ 已切换到 Java $version ($package)" -ForegroundColor Green
    Write-Host "   JAVA_HOME = $jdkPath"
    Write-Host "   Java版本: $javaVersion"
}

Set-Alias jv jdk-switch