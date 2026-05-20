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

# 默认模拟器路径（雷电模拟器 LDPlayer9）
if (-not $emulatorPath) {
    $defaultPaths = @(
        "D:\Soft\leidian\LDPlayer9\dnplayer.exe",
        "D:\leidian\LDPlayer9\dnplayer.exe",
        "${Env:ProgramFiles}\LDPlayer\LDPlayer9\dnplayer.exe"
    )
    $emulatorPath = $defaultPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

# 检查模拟器路径
if (-not $emulatorPath -or -not (Test-Path $emulatorPath)) {
    Write-Warning "模拟器路径未找到，请设置: `$Env:EMULATOR_PATH = 'D:\Soft\leidian\LDPlayer9\dnplayer.exe'"
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

# 等待模拟器设备出现（最长等 120 秒）
$maxWait = 120
$elapsed = 0
$deviceId = $null
while ($elapsed -lt $maxWait) {
    Start-Sleep -Seconds 5
    $elapsed += 5

    # 从 adb devices 中查找模拟器设备
    $devices = adb devices | Select-String -Pattern "^\S+\s+device$"
    foreach ($line in $devices) {
        $serial = ($line.Line -split "\s+")[0]
        if ($serial -match "^emulator-\d+$" -or $serial -match "^127\.0\.0\.1:\d+$") {
            $deviceId = $serial
            break
        }
    }
    if ($deviceId) { break }
    Write-Host "  等待模拟器启动... ($elapsed/$maxWait s)" -ForegroundColor DarkGray
}
if (-not $deviceId) {
    Write-Error "模拟器未在 ${maxWait} 秒内启动，未检测到模拟器设备"
    return
}

# 等待系统完成启动
$bootStatus = ""
while ($bootStatus -ne "1") {
    Start-Sleep -Seconds 3
    $bootStatus = adb -s $deviceId shell getprop sys.boot_completed 2>&1
}
Write-Host "模拟器已就绪 (设备: $deviceId)" -ForegroundColor Green

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