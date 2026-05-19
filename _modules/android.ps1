<#
.SYNOPSIS
    Android APK 工具集
.DESCRIPTION
    APK 信息提取、签名、反编译、重编译、安全检测等
    依赖: adb, aapt2, apktool, apksigner, 7z, keytool
#>

# ========== 环境初始化 ==========

function Initialize-AndroidEnv {
    if (-not (Test-PathEx $Env:ANDROID_HOME)) {
        Write-Warning "ANDROID_HOME 未设置，部分功能可能不可用"
        return
    }
    
    Add-PathToEnv "$($Env:ANDROID_HOME)\platform-tools"
    
    $buildTools = @(Get-ChildItem "$($Env:ANDROID_HOME)\build-tools" -ErrorAction SilentlyContinue | Select-Object Name)[-1].Name
    if ($buildTools) { Add-PathToEnv "$($Env:ANDROID_HOME)\build-tools\$buildTools" }
    
    $ndk = @(Get-ChildItem "$($Env:ANDROID_HOME)\ndk" -ErrorAction SilentlyContinue | Select-Object Name)[-1].Name
    if ($ndk) {
        $Env:ANDROID_NDK_HOME = "$($Env:ANDROID_HOME)\ndk\$ndk"
        Add-PathToEnv $Env:ANDROID_NDK_HOME
    }
    
    # 生成 debug keystore（如果没有）
    $androidDir = "$env:USERPROFILE\.android"
    $keystorePath = "$androidDir\debug.p12"
    if (-not (Test-PathEx $keystorePath)) {
        if (-not (Test-PathEx $androidDir)) { New-Item -ItemType Directory -Path $androidDir | Out-Null }
        keytool -genkeypair -v -keystore $keystorePath -storetype PKCS12 -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" 2>$null
    }
}

# ========== APK 信息提取 ==========

function Get-ApkInfo {
    param([Parameter(Mandatory)][string]$Path)
    
    $Path = Resolve-Path -Path $Path
    if (-not (Test-PathEx $Path)) { Write-Warning "文件不存在: $Path"; return }
    
    $output = & aapt2 dump badging $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw $output }
    
    [PSCustomObject]@{
        Label    = [regex]::Match($output, "application:\slabel='([^']+)'").Groups[1].Value
        Package  = [regex]::Match($output, "package:\sname='([^']+)'").Groups[1].Value
        Version  = [regex]::Match($output, "versionName='([^']+)'").Groups[1].Value
        VersionCode = [regex]::Match($output, "versionCode='([^']+)'").Groups[1].Value
    } | Format-List
}

function Get-ApkSignInfo {
    param([Parameter(Mandatory)][string]$Path)
    & apksigner verify --print-certs-pem (Resolve-Path -Path $Path)
}

function Get-JarSignInfo {
    param([Parameter(Mandatory)][string]$Path)
    & keytool -printcert -jarfile (Resolve-Path -Path $Path)
}

function Get-ApkLibs {
    param([Parameter(Mandatory)][string]$Path)
    & 7z l (Resolve-Path -Path $Path) | Select-String "\.so$"
}

function Get-ApkProtectInfo {
    param([Parameter(Mandatory)][string]$Path)
    if (Get-Command apkid -ErrorAction SilentlyContinue) {
        & apkid (Resolve-Path -Path $Path)
    } else {
        Write-Warning "apkid 未安装，跳过加固检测"
    }
}

# ========== APK 混淆信息检测 ==========

function Get-AppObfuscInfo {
    param([Parameter(Mandatory)][string]$Path)
    
    $toolPath = $Env:APPOBFUSC_TOOL
    if (-not $toolPath -or -not (Test-Path $toolPath)) {
        Write-Warning "APPOBFUSC_TOOL 未设置或路径不存在"
        Write-Warning "请设置: `$Env:APPOBFUSC_TOOL = 'path\to\appinfo.py'"
        return
    }
    
    & python $toolPath (Resolve-Path -Path $Path)
}

# ========== ADB APK 提取 ==========

function Get-DeviceApk {
    param(
        [string]$Package,
        [string]$OutputDir = ".",
        [switch]$Foreground
    )
    
    if (-not (Test-CommandExists adb)) { Write-Error "adb 未找到，请确认 ANDROID_HOME 已设置"; return }
    
    $devices = adb devices | Where-Object { $_ -match "device$" }
    if (-not $devices) { Write-Error "未检测到已连接设备"; return }
    
    # 未指定包名且非前台模式时，列出已安装的第三方应用
    if (-not $Package -and -not $Foreground) {
        Write-Host "已安装的第三方应用:" -ForegroundColor Cyan
        adb shell pm list packages -3 | ForEach-Object { $_ -replace "package:", "" } | Sort-Object
        return
    }
    
    # 获取前台应用包名
    if ($Foreground -and -not $Package) {
        # 使用 dumpsys window 获取当前焦点应用（最准确）
        $focusLine = adb shell dumpsys window 2>&1 | Select-String "mCurrentFocus" | Select-Object -First 1
        
        if ($focusLine -match "Window\{.*?\s+([a-zA-Z0-9_.]+)/") {
            $Package = $Matches[1]
        } else {
            # 备用方案：dumpsys activity
            $focusLine = adb shell dumpsys activity activities 2>&1 | Select-String "topResumedActivity" | Select-Object -First 1
            if ($focusLine -match "u\d+\s+([a-zA-Z0-9_.]+)/") {
                $Package = $Matches[1]
            }
        }
        
        if (-not $Package) {
            Write-Error "无法获取前台应用"
            return
        }
        Write-Host "前台应用: $Package" -ForegroundColor Cyan
    }
    
    # 获取 APK 路径
    $apkPath = adb shell pm path $Package 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $apkPath) {
        Write-Error "未找到包: $Package"
        return
    }
    
    # 处理多个 APK（split APKs）
    $apkList = @($apkPath -split "`n" | ForEach-Object { ($_ -replace "package:", "").Trim() } | Where-Object { $_ })
    
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
    
    foreach ($remotePath in $apkList) {
        $fileName = [IO.Path]::GetFileName($remotePath)
        $localPath = Join-Path $OutputDir $fileName
        Write-Host "拉取: $remotePath" -ForegroundColor Yellow
        adb pull $remotePath $localPath
        Write-Host "✓ 已保存: $localPath" -ForegroundColor Green
    }
    
    # 显示 APK 信息
    if ($apkList.Count -gt 0) {
        $mainApk = Join-Path $OutputDir ([IO.Path]::GetFileName($apkList[0]))
        if (Test-Path $mainApk) {
            Write-Host "`nAPK 信息:" -ForegroundColor Cyan
            Get-ApkInfo $mainApk
        }
    }
}

Set-Alias -Name pullapk -Value Get-DeviceApk -Scope Global

Set-Alias -Name apkinfo -Value Get-ApkInfo -Scope Global
Set-Alias -Name apksign -Value Get-ApkSignInfo -Scope Global
Set-Alias -Name jarsign -Value Get-JarSignInfo -Scope Global
Set-Alias -Name apklibs -Value Get-ApkLibs -Scope Global
Set-Alias -Name apkprotect -Value Get-ApkProtectInfo -Scope Global
Set-Alias -Name appinfo -Value Get-AppObfuscInfo -Scope Global
Set-Alias -Name decompile -Value Decompile-Apk -Scope Global
Set-Alias -Name recompile -Value Recompile-Apk -Scope Global
Set-Alias -Name signapk -Value Sign-Apk -Scope Global
Set-Alias -Name testapk -Value Test-RebuiltApk -Scope Global
Set-Alias -Name testemu -Value Test-EmulatorApk -Scope Global
Set-Alias -Name testlib -Value Test-ApkLib -Scope Global

# ========== 反编译/重编译/签名 ==========

function Decompile-Apk {
    param(
        [Parameter(Mandatory)][string]$ApkPath,
        [switch]$Force
    )
    
    if (-not (Test-Path $ApkPath)) { Write-Error "文件不存在: $ApkPath"; return }
    if (-not (Test-CommandExists apktool)) { Write-Error "请先安装: scoop install apktool"; return }
    
    $outputDir = [IO.Path]::ChangeExtension($ApkPath, $null)
    if ((Test-Path $outputDir) -and -not $Force) {
        Write-Error "目录已存在: $outputDir (使用 -Force 覆盖)"; return
    }
    
    & apktool d $ApkPath -o $outputDir -f
    Write-Host "✓ 反编译完成: $outputDir" -ForegroundColor Green
}

function Recompile-Apk {
    param(
        [Parameter(Mandatory)][string]$DecompiledDir,
        [switch]$Force
    )
    
    if (-not (Test-Path $DecompiledDir)) { Write-Error "目录不存在: $DecompiledDir"; return }
    if (-not (Test-CommandExists apktool)) { Write-Error "请先安装: scoop install apktool"; return }
    
    $apkName = [IO.Path]::GetFileNameWithoutExtension($DecompiledDir) + "_rebuilt.apk"
    $outputApk = Join-Path ([IO.Path]::GetDirectoryName($DecompiledDir)) $apkName
    
    if ((Test-Path $outputApk) -and -not $Force) {
        Write-Error "文件已存在: $outputApk (使用 -Force 覆盖)"; return
    }
    
    & apktool b $DecompiledDir -o $outputApk
    Write-Host "✓ 重编译完成: $outputApk" -ForegroundColor Green
}

function Sign-Apk {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$KeystorePath = "$env:USERPROFILE\.android\debug.p12",
        [string]$StorePass = "android",
        [string]$Alias = "androiddebugkey"
    )
    
    $Path = Resolve-Path -Path $Path
    $file = Get-ChildItem $Path
    $signedPath = Join-Path $file.DirectoryName "$($file.BaseName)_signed$($file.Extension)"
    
    Copy-Item $Path $signedPath -Force
    & 7z d $signedPath "META-INF\*" -r -y 2>$null
    & apksigner sign --ks (Resolve-Path $KeystorePath) --ks-key-alias $Alias --ks-pass "pass:$StorePass" --out $signedPath $signedPath
    
    Write-Host "✓ 签名完成: $signedPath" -ForegroundColor Green
}

# ========== 自动化测试 ==========

function Test-RebuiltApk {
    param([Parameter(Mandatory)][string]$ApkPath)
    $BaseDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell"
    & "$BaseDir\_modules\Test-RebuiltApk.ps1" -install -screenshot -force -apkPath (Resolve-Path $ApkPath)
}

function Test-EmulatorApk {
    param([string]$EmulatorName)
    $BaseDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell"
    $params = @{}
    if ($EmulatorName) { $params["EmulatorName"] = $EmulatorName }
    & "$BaseDir\_modules\Test-Emulator.ps1" @params
}

function Test-ApkLib {
    param([string]$ApkPath)
    $BaseDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell"
    $params = @{}
    if ($ApkPath) { $params["ApkPath"] = $ApkPath }
    & "$BaseDir\_modules\Test-Lib.ps1" @params
}

# ========== 配置 ==========
# 外部工具路径（根据实际情况修改）
if (-not $Env:APPOBFUSC_TOOL) {
    $Env:APPOBFUSC_TOOL = "D:\SecTools\AppTools\apphide\appinfo\appinfo.py"
}

# 初始化
Initialize-AndroidEnv
