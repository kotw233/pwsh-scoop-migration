<#
.SYNOPSIS
    APK重打包工具
.DESCRIPTION
    自动反编译、重打包、签名APK文件，可选安装到设备并截图
.EXAMPLE
    .\Rebuilt-Apk.ps1 -apkPath "C:\test.apk" -install -screenshot
#>

param (
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) { throw "APK文件不存在: $_" }
        if ($_ -notmatch '\.apk$') { throw "请指定有效的APK文件(.apk扩展名)" }
        $true
    })]
    [string]$apkPath,
    [string]$keystorePath = "$env:USERPROFILE\.android\debug.p12",
    [string]$storePass = "android",
    [string]$alias = "androiddebugkey",
    [switch]$force,
    [switch]$install,
    [switch]$screenshot
)

# 检查依赖工具
$requiredTools = @("apktool", "apksigner", "7z", "adb", "aapt")
$missingTools = @()
foreach ($tool in $requiredTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $missingTools += $tool
    }
}
if ($missingTools.Count -gt 0) {
    Write-Error "缺少必要工具，请先安装: $($missingTools -join ', ')"
    Write-Host "安装建议:"
    Write-Host "  apktool: 'scoop install apktool'下载"
    Write-Host "  apksigner: 包含在Android SDK中"
    Write-Host "  7z: Windows用户可安装7-Zip"
    Write-Host "  adb & aapt: 包含在Android SDK Platform-Tools中"
    exit 1
}

# 解析APK路径
$apkPath = Resolve-Path $apkPath -ErrorAction Stop | Select-Object -ExpandProperty Path
$apkDir = [IO.Path]::GetDirectoryName($apkPath)
$apkName = [IO.Path]::GetFileNameWithoutExtension($apkPath)

# 1. 反编译APK
$outputDir = Join-Path $apkDir "$apkName-decompiled"
if (Test-Path $outputDir) {
    if (-not $force) {
        Write-Error "目录已存在: $outputDir (使用 -force 覆盖)"
        exit 1
    }
    Remove-Item $outputDir -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "开始反编译APK: $apkPath" -ForegroundColor Cyan
apktool d $apkPath -o $outputDir -f
if ($LASTEXITCODE -ne 0) {
    Write-Error "反编译失败 (错误码: $LASTEXITCODE)"
    exit 1
}

# 2. 重编译APK
$rebuiltApk = Join-Path $apkDir "$apkName-rebuilt.apk"
if (Test-Path $rebuiltApk) {
    if (-not $force) {
        Write-Error "文件已存在: $rebuiltApk (使用 -force 覆盖)"
        exit 1
    }
    Remove-Item $rebuiltApk -Force -ErrorAction SilentlyContinue
}
Write-Host "开始重编译APK..." -ForegroundColor Cyan
apktool b $outputDir -o $rebuiltApk
if ($LASTEXITCODE -ne 0) {
    Write-Error "重编译失败 (错误码: $LASTEXITCODE)"
    exit 1
}

# 3. 签名APK
$signedApkPath = Join-Path $apkDir "$apkName-signed.apk"
if (Test-Path $signedApkPath) { Remove-Item $signedApkPath -Force -ErrorAction SilentlyContinue }
Write-Host "开始签名APK..." -ForegroundColor Cyan
Copy-Item $rebuiltApk -Destination $signedApkPath -Force
7z d "$signedApkPath" "META-INF\*" -r -y > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "删除原签名文件时出错 (代码: $LASTEXITCODE)，继续签名操作..."
}
apksigner sign --ks $keystorePath --ks-key-alias $alias --ks-pass "pass:$storePass" --out $signedApkPath $signedApkPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "签名失败 (错误码: $LASTEXITCODE)"
    exit 1
}

# 可选：安装并截图
if ($install) {
    Write-Host "正在安装APK到手机..." -ForegroundColor Cyan
    adb install -r $signedApkPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "安装失败 (错误码: $LASTEXITCODE)"
        exit 1
    }
    $packageInfo = aapt dump badging $signedApkPath 2>&1
    $packageName = $packageInfo | Select-String "package: name='([^']+)'" | ForEach-Object { $_.Matches.Groups[1].Value }
    $launchActivity = $packageInfo | Select-String "launchable-activity: name='([^']+)'" | ForEach-Object { $_.Matches.Groups[1].Value }
    if (-not $packageName -or -not $launchActivity) {
        Write-Warning "无法自动获取主Activity，请手动启动应用"
    } else {
        Write-Host "正在启动应用: $packageName/$launchActivity" -ForegroundColor Cyan
        adb shell am start -n "$packageName/$launchActivity"
        Start-Sleep -Seconds 5
        if ($screenshot) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $screenshotPath = Join-Path $apkDir "$apkName-screenshot-$timestamp.png"
            Write-Host "正在截取应用画面..." -ForegroundColor Cyan
            adb shell screencap -p /sdcard/screenshot.png
            if ($LASTEXITCODE -eq 0) {
                adb pull /sdcard/screenshot.png $screenshotPath
                adb shell rm /sdcard/screenshot.png
                if (Test-Path $screenshotPath) {
                    Write-Host "截图已保存: $screenshotPath" -ForegroundColor Green
                } else {
                    Write-Warning "截图保存失败"
                }
            } else {
                Write-Warning "截图失败，请检查设备是否支持"
            }
        }
    }
}
Write-Host "`n处理完成!" -ForegroundColor Green
Write-Host "签名APK路径: $signedApkPath" -ForegroundColor Yellow
if ($install) { Write-Host "已安装到设备" -ForegroundColor Yellow }