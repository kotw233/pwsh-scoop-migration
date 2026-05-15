# scoop.ps1 - Scoop 管理工具

# 检查 scoop 是否安装
function Test-ScoopInstalled {
    return [bool](Get-Command scoop -ErrorAction SilentlyContinue)
}

# ========== 简化命令 ==========

function Invoke-ScoopInstall { scoop install @args }
function Invoke-ScoopUpdate { scoop update @args }
function Invoke-ScoopUninstall { scoop uninstall @args }
function Invoke-ScoopSearch { scoop search @args }
function Invoke-ScoopList { scoop list @args }
function Invoke-ScoopInfo { scoop info @args }
function Invoke-ScoopBucket { scoop bucket @args }
function Invoke-ScoopStatus { scoop status @args }
function Invoke-ScoopCleanup { scoop cleanup @args }
function Invoke-ScoopCache { scoop cache @args }

# ========== 版本切换 ==========

# aria2 加速开关
function Enable-Aria2 { scoop config aria2-enabled true }
function Disable-Aria2 { scoop config aria2-enabled false }

# 列出已安装的 Python
function Get-InstalledPython {
    scoop list | Where-Object { $_ -match "(?i)python" }
}

# 列出已安装的 JDK
function Get-InstalledJdk {
    scoop list | Where-Object { $_ -match "(?i)jdk|java" }
}

# 切换 Java 版本
function Switch-Java {
    param([Parameter(Mandatory)][int]$Version)
    
    $package = switch ($Version) {
        8 { "openjdk8-redhat" }
        default { "openjdk$Version" }
    }
    
    $installed = scoop list $package 2>$null | Where-Object { $_ -match "^$package\s" }
    if (-not $installed) {
        Write-Host "✗ $package 未安装，请先执行: scoop install $package" -ForegroundColor Red
        return
    }
    
    scoop reset $package
    $jdkPath = scoop prefix $package
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkPath, 'User')
    $javaVersion = (java -version 2>&1 | Select-String "version").Line
    Write-Host "✓ 已切换到 Java $Version ($package)" -ForegroundColor Green
    Write-Host "  JAVA_HOME = $jdkPath"
    Write-Host "  $javaVersion"
}

# 切换 Python 版本
function Switch-Python {
    param([Parameter(Mandatory)][string]$Version)
    
    $package = "python$Version"
    $installed = scoop list $package 2>$null | Where-Object { $_ -match "^$package\s" }
    if (-not $installed) {
        Write-Host "✗ $package 未安装，请先执行: scoop install $package" -ForegroundColor Red
        return
    }
    
    scoop reset $package
    $pyPath = scoop prefix $package
    Write-Host "✓ 已切换到 Python $Version ($package)" -ForegroundColor Green
    Write-Host "  Python 路径: $pyPath\python.exe"
    python --version
}


