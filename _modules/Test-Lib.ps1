<#
.SYNOPSIS
    APK文件安全检测工具
.DESCRIPTION
    自动解压APK并检测.so文件安全特性，参数校验和错误处理完善
.EXAMPLE
    .\Test-Lib.ps1 -ApkPath "C:\test.apk"
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="请输入APK文件完整路径")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) { throw "文件不存在或不是有效的APK文件路径" }
        if ($_ -notmatch '\.apk$') { throw "请指定有效的APK文件(.apk扩展名)" }
        $true
    })]
    [string]$ApkPath
)

# 创建临时目录
$tempDir = Join-Path $env:TEMP ("apk_" + [System.IO.Path]::GetFileNameWithoutExtension($ApkPath) + "_" + (Get-Date -Format "yyyyMMddHHmmss"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

function Expand-Apk {
    param(
        [string]$ApkFile,
        [string]$OutputDir
    )
    
    try {
        # 检查7z命令是否可用
        $7zAvailable = Get-Command "7z" -ErrorAction SilentlyContinue
        if (-not $7zAvailable) {
            throw "7z命令不可用，请确保7-Zip已安装且已添加到系统PATH环境变量，可使用命令'scoop install 7zip'进行安装"
        }
        
        Write-Host "正在使用7z解压APK..." -ForegroundColor Cyan
        & 7z x "-o$OutputDir" "-y" $ApkFile | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "APK解压失败(错误码: $LASTEXITCODE)"
        }
    }
    catch {
        Write-Error "解压APK时出错: $_"
        exit 1
    }
}

function Test-StackProtection {
    param(
        [string]$LibsDir
    )
    
    $soFiles = Get-ChildItem -Path $LibsDir -Recurse -Filter "*.so" | Where-Object {
        $_.Name -notin @("libsecexe.so", "libsecmain.so", "libDexHelper.so", "libDexHelper-x86.so")
    }
    
    $missingGuard = @()
    
    foreach ($file in $soFiles) {
        try {
            $result = findstr /M /C:"stack_chk_guard" $file.FullName 2>$null
            if (-not $result) {
                $relativePath = $file.FullName.Substring($LibsDir.Length + 1)
                $missingGuard += $relativePath
            }
        } catch {
            Write-Warning "检查文件失败: $($file.FullName)"
        }
    }
    
    Write-Host "`n=============== 堆栈保护检查 ===============" -ForegroundColor Cyan
    if ($missingGuard.Count -eq 0) {
        Write-Host "[√] 所有.so文件已启用堆栈保护" -ForegroundColor Green
    } else {
        Write-Host "[×] 以下.so文件未启用堆栈保护:" -ForegroundColor Red
        $missingGuard | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host ""
}

function Test-AddressRandomization {
    param(
        [string]$LibsDir
    )
    
    $soFiles = Get-ChildItem -Path $LibsDir -Recurse -Filter "*.so" | Where-Object {
        $_.Name -notin @("libsecexe.so", "libsecmain.so", "libDexHelper.so", "libDexHelper-x86.so")
    }
    
    $missingDyn = @()
    
    foreach ($file in $soFiles) {
        try {
            $header = [System.IO.File]::ReadAllBytes($file.FullName)[0..63]
            if ($header[0] -eq 0x7F -and $header[1] -eq 0x45 -and $header[2] -eq 0x4C -and $header[3] -eq 0x46) {
                if ($header[16] -ne 3) {
                    $relativePath = $file.FullName.Substring($LibsDir.Length + 1)
                    $missingDyn += $relativePath
                }
            }
        } catch {
            Write-Warning "解析文件失败: $($file.FullName)"
        }
    }
    
    Write-Host "`n============ 地址随机化检查 ============" -ForegroundColor Cyan
    if ($missingDyn.Count -eq 0) {
        Write-Host "[√] 所有.so文件已启用地址随机化" -ForegroundColor Green
    } else {
        Write-Host "[×] 以下.so文件未启用地址随机化:" -ForegroundColor Red
        $missingDyn | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host ""
}

try {
    Write-Host "开始检测APK: $ApkPath" -ForegroundColor Yellow
    
    # 解压APK
    Expand-Apk -ApkFile $ApkPath -OutputDir $tempDir
    
    # 查找lib目录
    $libDir = Join-Path $tempDir "lib"
    if (-not (Test-Path $libDir)) {
        Write-Warning "APK中未找到lib目录，可能没有原生库文件"
        exit 0
    }
    
    # 执行检测
    Test-StackProtection -LibsDir $libDir
    Test-AddressRandomization -LibsDir $libDir
}
catch {
    Write-Error "检测失败: $_"
    exit 1
}
finally {
    # 清理临时文件
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "已清理临时文件: $tempDir" -ForegroundColor DarkGray
    }
}