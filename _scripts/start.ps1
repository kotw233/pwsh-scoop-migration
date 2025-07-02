#start-alias

function Start-Burp {
    $vbsPath = "D:\Program_base\Scoop\apps\burp-suite-pro-np\current\BurpSuitePro.vbs"
    if (Test-Path $vbsPath) {
        Start-Process wscript.exe -ArgumentList "`"$vbsPath`""
    } else {
        Write-Host "❌ Burp Suite VBS 脚本未找到" -ForegroundColor Red
    }
}

Set-Alias burp Start-Burp

#Set-Alias
Set-Alias vs code
Set-Alias s history
Set-Alias sudo gsudo
Set-Alias sand sandboxie-start
Set-Alias v2 v2rayN
Set-Alias hibit "D:\Program_base\Scoop\apps\hibit-uninstaller\current\HiBitUninstaller-Portable.exe"
Set-Alias openArk "D:\Program_base\Scoop\apps\openark\current\OpenArk.exe"