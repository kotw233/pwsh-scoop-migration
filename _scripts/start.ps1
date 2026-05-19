# start.ps1 - 快捷启动命令

# 获取 scoop 应用路径
function Get-ScoopAppPath {
    param([string]$AppName)
    $scoopPath = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
    return "$scoopPath\apps\$AppName\current"
}

# 启动 Burp Suite
function Start-Burp {
    $vbsPath = Join-Path (Get-ScoopAppPath "burp-suite-pro-np") "BurpSuitePro.vbs"
    if (Test-Path $vbsPath) {
        Start-Process wscript.exe -ArgumentList "`"$vbsPath`""
    } else {
        Write-Host "✗ Burp Suite 未安装或路径错误" -ForegroundColor Red
    }
}



# 动态获取 scoop 应用路径的启动函数
function Start-ScoopApp {
    param([Parameter(Mandatory)][string]$AppName)
    $appPath = Get-ScoopAppPath $AppName
    $exe = Get-ChildItem "$appPath\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe.FullName
        $psi.UseShellExecute = $true
        $psi.CreateNoWindow = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } else {
        Write-Host "✗ $AppName 未找到可执行文件" -ForegroundColor Red
    }
}



