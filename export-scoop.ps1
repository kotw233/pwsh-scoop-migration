#
# export-scoop.ps1 - 导出 Scoop 配置
#

$OutputDir = $PSScriptRoot

# 导出 Buckets
Write-Host "导出 Buckets..." -ForegroundColor Cyan
scoop bucket list 2>$null | ForEach-Object { $_.Name } | Out-File "$OutputDir\buckets.txt" -Encoding UTF8
Write-Host "  ✓ buckets.txt" -ForegroundColor Green

# 导出已安装应用
Write-Host "导出已安装应用..." -ForegroundColor Cyan
scoop export 2>$null | Out-File "$OutputDir\installed_apps.json" -Encoding UTF8
Write-Host "  ✓ installed_apps.json" -ForegroundColor Green

Write-Host "`n完成！" -ForegroundColor Green
