<#
.SYNOPSIS
    Android APK 工具集
.DESCRIPTION
    APK 信息提取、签名、反编译、重编译、安全检测等
    依赖: adb, aapt2, apktool, apksigner, 7z, keytool
#>

# ========== 辅助函数 ==========

function Resolve-ValidPath {
    param([Parameter(Mandatory)][string]$Path)
    $resolved = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $PWD.Path $Path }
    if (-not (Test-Path $resolved)) {
        Write-Warning "路径不存在: $resolved"
        return $null
    }
    return $resolved
}

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
    
    $Path = Resolve-ValidPath $Path
    if (-not $Path) { return }
    
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
    $Path = Resolve-ValidPath $Path
    if (-not $Path) { return }
    & apksigner verify --print-certs-pem $Path
}

function Get-JarSignInfo {
    param([Parameter(Mandatory)][string]$Path)
    $Path = Resolve-ValidPath $Path
    if (-not $Path) { return }
    & keytool -printcert -jarfile $Path
}

function Get-ApkLibs {
    param([Parameter(Mandatory)][string]$Path)
    $Path = Resolve-ValidPath $Path
    if (-not $Path) { return }
    & 7z l $Path | Select-String "\.so$"
}

function Get-ApkProtectInfo {
    param([Parameter(Mandatory)][string]$Path)
    if (Get-Command apkid -ErrorAction SilentlyContinue) {
        $Path = Resolve-ValidPath $Path
        if (-not $Path) { return }
        & apkid $Path
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
    
    $Path = Resolve-ValidPath $Path
    if (-not $Path) { return }
    & python $toolPath $Path
}

# ========== ADB APK 提取 ==========

function Get-AdbPath {
    if (Get-Command adb -ErrorAction SilentlyContinue) { return "adb" }
    if ($Env:ANDROID_HOME -and (Test-Path "$Env:ANDROID_HOME\platform-tools\adb.exe")) {
        return "$Env:ANDROID_HOME\platform-tools\adb.exe"
    }
    return $null
}

function Get-DeviceApk {
    param(
        [string]$Package,
        [string]$OutputDir = ".",
        [switch]$Foreground
    )
    
    $adb = Get-AdbPath
    if (-not $adb) { Write-Error "adb 未找到，请确认 ANDROID_HOME 已设置"; return }
    
    $devices = & $adb devices | Where-Object { $_ -match "device$" }
    if (-not $devices) { Write-Error "未检测到已连接设备"; return }
    
    # 未指定包名且非前台模式时，列出已安装的第三方应用
    if (-not $Package -and -not $Foreground) {
        Write-Host "已安装的第三方应用:" -ForegroundColor Cyan
        & $adb shell pm list packages -3 | ForEach-Object { $_ -replace "package:", "" } | Sort-Object
        return
    }
    
    # 获取前台应用包名
    if ($Foreground -and -not $Package) {
        $focusLine = & $adb shell dumpsys window 2>&1 | Select-String "mCurrentFocus" | Select-Object -First 1
        
        if ($focusLine -match "Window\{.*?\s+([a-zA-Z0-9_.]+)/") {
            $Package = $Matches[1]
        } else {
            $focusLine = & $adb shell dumpsys activity activities 2>&1 | Select-String "topResumedActivity" | Select-Object -First 1
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
    $apkPath = & $adb shell pm path $Package 2>&1
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
        & $adb pull $remotePath $localPath
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

# ========== ADB 应用数据 ==========

function Get-AppData {
    param(
        [string]$Package,
        [string]$OutputDir = "."
    )
    
    $adb = Get-AdbPath
    if (-not $adb) { Write-Error "adb 未找到"; return }
    
    $devices = & $adb devices | Where-Object { $_ -match "device$" }
    if (-not $devices) { Write-Error "未检测到已连接设备"; return }
    
    # 未指定包名时获取前台应用
    if (-not $Package) {
        $focusLine = & $adb shell dumpsys window 2>&1 | Select-String "mCurrentFocus" | Select-Object -First 1
        if ($focusLine -match "Window\{.*?\s+([a-zA-Z0-9_.]+)/") {
            $Package = $Matches[1]
        } else {
            Write-Error "无法获取前台应用，请指定包名"; return
        }
    }
    
    Write-Host "应用: $Package" -ForegroundColor Cyan
    
    # 检测 root 权限
    $whoami = & $adb shell whoami 2>&1
    $isRoot = $whoami -match "root"
    
    if ($isRoot) {
        Write-Host "权限: root" -ForegroundColor Green
        & $adb pull "/data/data/$Package" (Join-Path $OutputDir $Package)
    } else {
        Write-Host "权限: 非 root，尝试 su" -ForegroundColor Yellow
        & $adb shell "su -c cp -r /data/data/$Package /sdcard/ 2>/dev/null"
        & $adb pull "/sdcard/$Package" (Join-Path $OutputDir $Package)
        & $adb shell "su -c rm -rf /sdcard/$Package" 2>$null
    }
    
    Write-Host "✓ 已保存到: $(Join-Path $OutputDir $Package)" -ForegroundColor Green
}

function Get-AppSandbox {
    param(
        [string]$Package,
        [switch]$Files
    )
    
    $adb = Get-AdbPath
    if (-not $adb) { Write-Error "adb 未找到"; return }
    
    $devices = & $adb devices | Where-Object { $_ -match "device$" }
    if (-not $devices) { Write-Error "未检测到已连接设备"; return }
    
    # 未指定包名时获取前台应用
    if (-not $Package) {
        $focusLine = & $adb shell dumpsys window 2>&1 | Select-String "mCurrentFocus" | Select-Object -First 1
        if ($focusLine -match "Window\{.*?\s+([a-zA-Z0-9_.]+)/") {
            $Package = $Matches[1]
        } else {
            Write-Error "无法获取前台应用，请指定包名"; return
        }
    }
    
    Write-Host "应用: $Package" -ForegroundColor Cyan
    
    # 检测 root 权限
    $whoami = & $adb shell whoami 2>&1
    $isRoot = $whoami -match "root"
    
    if ($Files) {
        # 查找敏感文件
        Write-Host "`n敏感文件:" -ForegroundColor Cyan
        $sensitiveExtensions = @("*.p12", "*.db", "*.xml", "*.js", "*.plist", "*.txt", "*.sqlite", "*.lua", "*.html", "*.key", "*.pem", "*.jks")
        $basePath = if ($isRoot) { "/data/data/$Package" } else {
            & $adb shell "su -c ls /data/data/$Package" 2>$null | Out-Null
            "/data/data/$Package"
        }
        
        foreach ($ext in $sensitiveExtensions) {
            $result = & $adb shell "su -c 'find /data/data/$Package -name $ext 2>/dev/null'"
            if ($result) {
                $result | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
            }
        }
    } else {
        # 查看沙箱目录
        Write-Host "`n沙箱目录:" -ForegroundColor Cyan
        if ($isRoot) {
            & $adb shell "ls -la /data/data/$Package"
        } else {
            & $adb shell "su -c ls -la /data/data/$Package"
        }
    }
}

Set-Alias -Name pullapk -Value Get-DeviceApk -Scope Global
Set-Alias -Name pulldata -Value Get-AppData -Scope Global
Set-Alias -Name sandbox -Value Get-AppSandbox -Scope Global

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
    
    $Path = Resolve-ValidPath $Path
    if (-not $Path) { return }
    $KeystorePath = Resolve-ValidPath $KeystorePath
    if (-not $KeystorePath) { return }
    
    $file = Get-ChildItem $Path
    $signedPath = Join-Path $file.DirectoryName "$($file.BaseName)_signed$($file.Extension)"
    
    Copy-Item $Path $signedPath -Force

    # 检测已有签名并删除
    $zipContents = & 7z l $signedPath 2>&1
    if ($zipContents -match "META-INF/") {
        Write-Host "检测到已有签名，正在清除..." -ForegroundColor Yellow
        & 7z d $signedPath "META-INF\*" -r -y 2>$null
    }
    
    & apksigner sign --ks $KeystorePath --ks-key-alias $Alias --ks-pass "pass:$StorePass" --out $signedPath $signedPath
    if ($LASTEXITCODE -ne 0) { Write-Error "签名失败"; return }
    
    Write-Host "✓ 签名完成: $signedPath" -ForegroundColor Green
    $certInfo = & apksigner verify --print-certs $signedPath 2>&1 | Where-Object { $_ } | Select-Object -First 1
    if ($certInfo) { Write-Host "  $certInfo" -ForegroundColor Gray }
}

# ========== 自动化测试 ==========

function Test-RebuiltApk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ApkPath,
        [string]$AppNameSuffix = " [MODIFIED]",
        [switch]$NoModify
    )

    $ApkPath = Resolve-ValidPath $ApkPath
    if (-not $ApkPath) { return }

    $apkDir = [IO.Path]::GetDirectoryName($ApkPath)
    $baseName = [IO.Path]::GetFileNameWithoutExtension($ApkPath)

    # 反编译 → 修改 → 重编译
    if (-not $NoModify) {
        $decompiledDir = Join-Path $apkDir "${baseName}_tamper"
        Write-Host "[1/3] 反编译..." -ForegroundColor Cyan
        if (Test-Path $decompiledDir) { Remove-Item $decompiledDir -Recurse -Force }
        & apktool d $ApkPath -o $decompiledDir -f
        if ($LASTEXITCODE -ne 0) { Write-Error "反编译失败"; return }

        Write-Host "[2/3] 修改资源..." -ForegroundColor Cyan

        # 改 app_name（所有 strings.xml）
        $allStrings = Get-ChildItem -Path $decompiledDir -Filter "strings.xml" -Recurse -File
        $nameCount = 0
        foreach ($file in $allStrings) {
            $content = Get-Content $file.FullName -Raw -Encoding UTF8
            if ($content -match 'name="app_name"') {
                $oldVal = [regex]::Match($content, 'name="app_name"[^>]*>([^<]+)').Groups[1].Value
                $newContent = $content -replace '(name="app_name"[^>]*>)([^<]+)(</string>)', "`$1`$2$AppNameSuffix`$3"
                Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
                $newVal = [regex]::Match($newContent, 'name="app_name"[^>]*>([^<]+)').Groups[1].Value
                $relPath = $file.FullName.Replace($decompiledDir, "").TrimStart("\")
                Write-Host "  [$relPath]" -ForegroundColor Gray
                Write-Host "    app_name: $oldVal -> $newVal" -ForegroundColor Yellow
                $nameCount++
            }
        }
        if ($nameCount -eq 0) { Write-Host "  未找到 app_name" -ForegroundColor Yellow }

        # 改 versionCode + versionName（apktool.yml）
        $apktoolYml = Join-Path $decompiledDir "apktool.yml"
        if (Test-Path $apktoolYml) {
            $yml = Get-Content $apktoolYml -Raw -Encoding UTF8
            $ymlModified = $false

            if ($yml -match 'versionCode:\s*(\d+)') {
                $oldVer = $Matches[1]
                $newVer = [int]$oldVer + 1
                $yml = $yml -replace "(versionCode:\s*)\d+", "`$1$newVer"
                Write-Host "  [apktool.yml]" -ForegroundColor Gray
                Write-Host "    versionCode: $oldVer -> $newVer" -ForegroundColor Yellow
                $ymlModified = $true
            }

            if ($yml -match "versionName:\s*'?([^'`"]+)'?") {
                $oldName = $Matches[1]
                $newName = "${oldName}-mod"
                $yml = $yml -replace "(versionName:\s*'?)[^'`"]+('?)", "`$1$newName`$2"
                Write-Host "  [apktool.yml]" -ForegroundColor Gray
                Write-Host "    versionName: $oldName -> $newName" -ForegroundColor Yellow
                $ymlModified = $true
            }

            if ($ymlModified) { Set-Content -Path $apktoolYml -Value $yml -Encoding UTF8 -NoNewline }
        }

        Write-Host "[3/3] 重编译..." -ForegroundColor Cyan
        $rebuiltApk = Join-Path $apkDir "${baseName}_tamper.apk"
        if (Test-Path $rebuiltApk) { Remove-Item $rebuiltApk -Force }
        & apktool b $decompiledDir -o $rebuiltApk
        if ($LASTEXITCODE -ne 0) { Write-Error "重编译失败"; return }

        Remove-Item $decompiledDir -Recurse -Force -ErrorAction SilentlyContinue
        $ApkPath = $rebuiltApk
        Write-Host "✓ 重编译完成: $rebuiltApk" -ForegroundColor Green
        Write-Host ""
        $output = & aapt2 dump badging $rebuiltApk 2>&1
        $label = [regex]::Match($output, "application:\slabel='([^']+)'").Groups[1].Value
        $pkg = [regex]::Match($output, "package:\sname='([^']+)'").Groups[1].Value
        $ver = [regex]::Match($output, "versionName='([^']+)'").Groups[1].Value
        $verCode = [regex]::Match($output, "versionCode='([^']+)'").Groups[1].Value
        Write-Host "  应用名: $label" -ForegroundColor Gray
        Write-Host "  包名:   $pkg" -ForegroundColor Gray
        Write-Host "  版本:   $ver ($verCode)" -ForegroundColor Gray
    }

    # 签名
    Write-Host ""
    Write-Host "签名中..." -ForegroundColor Cyan
    $signedApk = Join-Path $apkDir "${baseName}_$(if (-not $NoModify) { 'tamper_' } else { '' })signed.apk"
    Copy-Item $ApkPath $signedApk -Force
    & 7z d $signedApk "META-INF\*" -r -y >$null 2>$null
    $keystorePath = "$env:USERPROFILE\.android\debug.p12"
    & apksigner sign --ks $keystorePath --ks-key-alias androiddebugkey --ks-pass "pass:android" --out $signedApk $signedApk
    if ($LASTEXITCODE -ne 0) { Write-Error "签名失败"; return }
    Write-Host "✓ 签名完成: $signedApk" -ForegroundColor Green
    $certInfo = & apksigner verify --print-certs $signedApk 2>&1 | Where-Object { $_ } | Select-Object -First 1
    if ($certInfo) { Write-Host "  $certInfo" -ForegroundColor Gray }

    if (-not $NoModify) {
        Remove-Item (Join-Path $apkDir "${baseName}_tamper.apk") -Force -ErrorAction SilentlyContinue
    }
}

function Test-EmulatorApk {
    param(
        [Parameter(Mandatory)]
        [string]$ApkPath,
        [string]$EmulatorName
    )
    $BaseDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell"
    $params = @{ apkPath = $ApkPath }
    if ($EmulatorName) { $params["avdName"] = $EmulatorName }
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
