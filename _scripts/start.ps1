# start.ps1 - 快捷启动命令

# 获取 scoop 应用路径
function Get-ScoopAppPath {
    param([string]$AppName)
    $scoopPath = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
    return "$scoopPath\apps\$AppName\current"
}

# 启动 Burp Suite（需要 VBS 启动器）
function Start-Burp {
    $vbsPath = Join-Path (Get-ScoopAppPath "burp-suite-pro-np") "BurpSuitePro.vbs"
    if (Test-Path $vbsPath) {
        Start-Process wscript.exe -ArgumentList "`"$vbsPath`""
    } else {
        Write-Host "✗ Burp Suite 未安装或路径错误" -ForegroundColor Red
    }
}
