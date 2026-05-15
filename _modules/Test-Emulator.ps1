<#
.SYNOPSIS
    自动化模拟器测试与截图工具
.DESCRIPTION
    启动模拟器、安装APK、自动截图，适用于自动化测试场景
.EXAMPLE
    .\Test-Emulator.ps1 -apkPath "C:\test.apk"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$apkPath,
    [string]$emulatorPath = $Env:EMULATOR_PATH,
    [string]$avdName = "dnplayer",
    [int]$waitSeconds = 10,
    [switch]$keepOpen
)

# 检查模拟器路径
if (-not $emulatorPath -or -not (Test-Path $emulatorPath)) {
    Write-Warning "EMULATOR_PATH 未设置或路径不存在"
    Write-Warning "请设置: `$Env:EMULATOR_PATH = 'D:\Soft\leidian\LDPlayer9\dnplayer.exe'"
    return
}

# 检查依赖工具
$requiredTools = @("adb", "aapt")
foreach ($tool in $requiredTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "缺少依赖工具: $tool"
        return
    }
}

# 解析APK信息
$apkPath = Resolve-Path $apkPath -ErrorAction Stop
$apkDir = [IO.Path]::GetDirectoryName($apkPath)
$apkName = [IO.Path]::GetFileNameWithoutExtension($apkPath)
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# 启动模拟器
Write-Host "`n=== 启动模拟器 ===" -ForegroundColor Cyan
$emulatorProcess = Start-Process -FilePath $emulatorPath -ArgumentList "@$avdName" -PassThru

do {
    Start-Sleep -Seconds 5
    $bootStatus = adb shell getprop sys.boot_completed 2>&1
} while ($bootStatus -ne "1")
Write-Host "模拟器已就绪" -ForegroundColor Green

# 获取设备ID
$deviceId = adb devices | Where-Object { $_ -match "^(emulator-\d+)\tdevice" } | ForEach-Object { $matches[1] }
if (-not $deviceId) {
    Write-Error "无法获取模拟器设备ID"
    return
}

# 安装APK
Write-Host "`n=== 安装APK ===" -ForegroundColor Cyan
adb -s $deviceId install -r $apkPath
if (-not $?) { Write-Error "安装失败"; return }

# 解析包信息并启动
Write-Host "`n=== 启动应用 ===" -ForegroundColor Cyan
$packageName = aapt dump badging $apkPath | Select-String "package: name='([^']+)'" | ForEach-Object { $_.Matches.Groups[1].Value }
$launchActivity = aapt dump badging $apkPath | Select-String "launchable-activity: name='([^']+)'" | ForEach-Object { $_.Matches.Groups[1].Value }
if ($packageName -and $launchActivity) {
    adb -s $deviceId shell am start -n "$packageName/$launchActivity"
    Start-Sleep -Seconds $waitSeconds
}

# 截图
Write-Host "`n=== 截取屏幕 ===" -ForegroundColor Cyan
$screenshotPath = Join-Path $apkDir "${apkName}-${timestamp}.png"
adb -s $deviceId shell screencap -p /sdcard/screenshot.png
adb -s $deviceId pull /sdcard/screenshot.png $screenshotPath
adb -s $deviceId shell rm /sdcard/screenshot.png

Write-Host "`n=== 操作完成 ===" -ForegroundColor Green
Write-Host "APK包名: $packageName"
Write-Host "截图路径: $screenshotPath"