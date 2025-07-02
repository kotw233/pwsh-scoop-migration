# _scripts/scoop.ps1

#   1、安装 Scoop 到 D:\Scoop，并恢复应用和 bucket
#   2、配置 Scoop 别名等

$SCOOP_PATH = "D:/Scoop"
$JsonFile = Join-Path $PSScriptRoot "../installed_apps.json"

# 设置 SCOOP 环境变量
$env:SCOOP = $SCOOP_PATH

# 如果未安装 Scoop，则安装
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "📦 正在安装 Scoop 到 $SCOOP_PATH" -ForegroundColor Cyan
    if (-not (Test-Path $SCOOP_PATH)) { New-Item -Path $SCOOP_PATH -ItemType Directory -Force | Out-Null }
    irm get.scoop.sh | iex
}

# 如果是首次加载且存在 installed_apps.json，则恢复状态
if (Test-Path $JsonFile) {
    Write-Host "🔄 正在导入 Scoop 应用列表..." -ForegroundColor Cyan

    try {
        $json = Get-Content $JsonFile -Raw | ConvertFrom-Json

        # 添加 buckets
        if ($json.buckets) {
            foreach ($bucket in $json.buckets) {
                Write-Host "📁 添加 bucket: $bucket"
                scoop bucket add $bucket 2>$null
            }
        }

        # 安装 apps
        if ($json.apps) {
            $apps = $json.apps.PSObject.Properties.Name
            if ($apps.Count -gt 0) {
                Write-Host "🎁 安装应用程序: $($apps -join ', ')"
                scoop install $apps
            }
        }
    } catch {
        Write-Warning "⚠️ 导入失败: $_"
    }
} else {
    Write-Host "📎 未找到 installed_apps.json，跳过恢复应用"
}

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