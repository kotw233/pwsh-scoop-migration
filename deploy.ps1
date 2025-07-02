#
# deploy.ps1
#

Copy-Item "profile.ps1" "$($Env:USERPROFILE)/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"

Copy-Item -Recurse -Force "_scripts/" "$($Env:USERPROFILE)/Documents/PowerShell/"

Write-Host "✅ PowerShell profile 已部署到：" -ForegroundColor Green
Write-Host "$($Env:USERPROFILE)/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"