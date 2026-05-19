# Utils.ps1 - 基础工具函数（必须最先加载）

# ========== 标准函数 ==========

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-PathEx {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    try { return (Test-Path -LiteralPath $Path -ErrorAction Stop) }
    catch { return $false }
}

function Add-PathToEnv {
    param([Parameter(Mandatory)][string]$NewPath)
    if (-not (Test-PathEx $NewPath)) { return }
    $currentPaths = $Env:Path.Split(";") | Where-Object { $_.Trim().Length -ne 0 }
    if ($currentPaths -contains $NewPath) { return }
    $Env:Path = ($currentPaths += $NewPath) -join ";"
}

function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-AllPaths {
    Write-Host "`n=== 系统 PATH ===" -ForegroundColor Cyan
    [Environment]::GetEnvironmentVariable("Path", "Machine") -split ';' | 
        ForEach-Object { $i = 1 } { "[SYS] $i`: $_"; $i++ }
    
    Write-Host "`n=== 用户 PATH ===" -ForegroundColor Yellow
    [Environment]::GetEnvironmentVariable("Path", "User") -split ';' | 
        ForEach-Object { $i = 1 } { "[USR] $i`: $_"; $i++ }
    
    Write-Host "`n=== 当前会话 PATH ===" -ForegroundColor Green
    $env:PATH -split ';' | 
        ForEach-Object { $i = 1 } { "[CUR] $i`: $_"; $i++ }
}

function Get-EnvVars {
    param([string]$Filter)
    $vars = Get-ChildItem Env:
    if ($Filter) { $vars = $vars | Where-Object { $_.Name -like "*$Filter*" } }
    $vars | Sort-Object Name | Format-Table -AutoSize
}

function Get-ExternalIP { curl myip.ipip.net }

function Open-Explorer { explorer (pwd).Path }

function ConvertTo-Base64 {
    param([Parameter(Mandatory)][string]$Content)
    [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Content))
}

function ConvertFrom-Base64 {
    param([Parameter(Mandatory)][string]$Content)
    [System.Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($Content))
}

function Get-FileHashMD5 { param([Parameter(Mandatory)][string]$Path) Get-FileHash -Algorithm MD5 $Path }
function Get-FileHashSHA1 { param([Parameter(Mandatory)][string]$Path) Get-FileHash -Algorithm SHA1 $Path }
function Get-FileHashSHA256 { param([Parameter(Mandatory)][string]$Path) Get-FileHash -Algorithm SHA256 $Path }

# ========== 统一别名管理 ==========

$aliasMap = @{
    "myip"      = "Get-ExternalIP"
    "ex"        = "Open-Explorer"
    "owp"       = "Open-Explorer"
    "b64e"      = "ConvertTo-Base64"
    "b64d"      = "ConvertFrom-Base64"
    "md5sum"    = "Get-FileHashMD5"
    "sha1sum"   = "Get-FileHashSHA1"
    "sha256sum" = "Get-FileHashSHA256"
    "proxy"     = "Set-Proxy"
    "unproxy"   = "Unset-Proxy"
    "ll"        = "Invoke-LsdLong"
    "la"        = "Invoke-LsdAll"
    "l"         = "Invoke-LsdHuman"
    "lt"        = "Invoke-LsdTree"
    "lS"        = "Invoke-LsdSize"
    "lsg"       = "Invoke-LsdGit"
    "lsrt"      = "Invoke-LsdTime"
    "lsz"       = "Invoke-LsdBig"
    "burp"      = "Start-Burp"
    "vs"        = "code"
    "s"         = "history"
    "sudo"      = "gsudo"
    "sand"      = "sandboxie-start"
    "lg"        = "lazygit"
    "jv"        = "Switch-Java"
    "pv"        = "Switch-Python"
    "aria2"     = "Enable-Aria2"
    "aria2off"  = "Disable-Aria2"
    "py-list"   = "Get-InstalledPython"
    "jdk-list"  = "Get-InstalledJdk"
    "ski"       = "Invoke-ScoopInstall"
    "sku"       = "Invoke-ScoopUpdate"
    "skr"       = "Invoke-ScoopUninstall"
    "sks"       = "Invoke-ScoopSearch"
    "skl"       = "Invoke-ScoopList"
    "skv"       = "Invoke-ScoopInfo"
    "skb"       = "Invoke-ScoopBucket"
    "skst"      = "Invoke-ScoopStatus"
    "skc"       = "Invoke-ScoopCleanup"
    "skca"      = "Invoke-ScoopCache"
    "cmds"      = "Get-MyCommands"
    "env"       = "Get-EnvVars"
    "ff"        = "fd"
    "rg"        = "rg"
}

foreach ($alias in $aliasMap.Keys) {
    Set-Alias -Name $alias -Value $aliasMap[$alias] -Scope Global
}

# ========== 命令帮助 ==========

function Get-MyCommands {
    Write-Host "`n=== 命令列表 ===" -ForegroundColor Cyan
    Write-Host ("  {0,-25} {1,-15} {2}" -f "标准命令", "别名", "说明") -ForegroundColor White
    Write-Host "  $('─' * 55)" -ForegroundColor DarkGray
    
    $commandList = @(
        @{ Cmd = "Get-ExternalIP"; Alias = "myip"; Desc = "查询外网 IP" },
        @{ Cmd = "Open-Explorer"; Alias = "ex/owp"; Desc = "资源管理器打开当前目录" },
        @{ Cmd = "ConvertTo-Base64"; Alias = "b64e"; Desc = "Base64 编码" },
        @{ Cmd = "ConvertFrom-Base64"; Alias = "b64d"; Desc = "Base64 解码" },
        @{ Cmd = "Get-FileHashMD5"; Alias = "md5sum"; Desc = "MD5 哈希" },
        @{ Cmd = "Get-FileHashSHA1"; Alias = "sha1sum"; Desc = "SHA1 哈希" },
        @{ Cmd = "Get-FileHashSHA256"; Alias = "sha256sum"; Desc = "SHA256 哈希" },
        @{ Cmd = "lsd -l"; Alias = "ll"; Desc = "长列表" },
        @{ Cmd = "lsd -alFh"; Alias = "la"; Desc = "完整列表" },
        @{ Cmd = "lsd -lFh"; Alias = "l"; Desc = "简洁列表" },
        @{ Cmd = "lsd --tree"; Alias = "lt"; Desc = "树形显示" },
        @{ Cmd = "lsd -l --size short"; Alias = "lS"; Desc = "文件大小" },
        @{ Cmd = "lsd -l --git"; Alias = "lsg"; Desc = "显示 git 状态" },
        @{ Cmd = "lsd -l --timesort"; Alias = "lsrt"; Desc = "按时间排序" },
        @{ Cmd = "lsd -l --sizesort"; Alias = "lsz"; Desc = "按大小排序" },
        @{ Cmd = "Set-Proxy"; Alias = "proxy"; Desc = "启用代理" },
        @{ Cmd = "Unset-Proxy"; Alias = "unproxy"; Desc = "禁用代理" },
        @{ Cmd = "Switch-Java"; Alias = "jv"; Desc = "切换 Java 版本" },
        @{ Cmd = "Switch-Python"; Alias = "pv"; Desc = "切换 Python 版本" },
        @{ Cmd = "Enable-Aria2"; Alias = "aria2"; Desc = "启用 aria2 加速" },
        @{ Cmd = "Disable-Aria2"; Alias = "aria2off"; Desc = "禁用 aria2" },
        @{ Cmd = "Get-InstalledPython"; Alias = "py-list"; Desc = "列出已安装 Python" },
        @{ Cmd = "Get-InstalledJdk"; Alias = "jdk-list"; Desc = "列出已安装 JDK" },
        @{ Cmd = "scoop install"; Alias = "ski"; Desc = "安装应用" },
        @{ Cmd = "scoop update"; Alias = "sku"; Desc = "更新应用" },
        @{ Cmd = "scoop uninstall"; Alias = "skr"; Desc = "卸载应用" },
        @{ Cmd = "scoop search"; Alias = "sks"; Desc = "搜索应用" },
        @{ Cmd = "scoop list"; Alias = "skl"; Desc = "列出已安装" },
        @{ Cmd = "scoop info"; Alias = "skv"; Desc = "查看应用信息" },
        @{ Cmd = "scoop bucket"; Alias = "skb"; Desc = "管理 bucket" },
        @{ Cmd = "scoop status"; Alias = "skst"; Desc = "查看状态" },
        @{ Cmd = "scoop cleanup"; Alias = "skc"; Desc = "清理缓存" },
        @{ Cmd = "Start-Burp"; Alias = "burp"; Desc = "启动 Burp Suite" },
        @{ Cmd = "code"; Alias = "vs"; Desc = "启动 VS Code" },
        @{ Cmd = "history"; Alias = "s"; Desc = "查看历史命令" },
        @{ Cmd = "gsudo"; Alias = "sudo"; Desc = "管理员提权" },
        @{ Cmd = "sandboxie-start"; Alias = "sand"; Desc = "启动 Sandboxie" },
        @{ Cmd = "lazygit"; Alias = "lg"; Desc = "lazygit" },
        @{ Cmd = "Get-MyCommands"; Alias = "cmds"; Desc = "列出所有命令" },
        @{ Cmd = "Get-EnvVars"; Alias = "env"; Desc = "列出环境变量" },
        @{ Cmd = "fzf"; Alias = "fzf"; Desc = "模糊搜索（Ctrl+R历史 Ctrl+T文件）" },
        @{ Cmd = "fd"; Alias = "ff"; Desc = "快速查找文件" },
        @{ Cmd = "rg"; Alias = "rg"; Desc = "快速搜索内容" },
        @{ Cmd = "touch"; Alias = "touch"; Desc = "创建文件/修改时间戳" },
        @{ Cmd = "Add-MyAlias"; Alias = "Add-MyAlias"; Desc = "添加别名" },
        @{ Cmd = "Remove-MyAlias"; Alias = "Remove-MyAlias"; Desc = "删除别名" },
        @{ Cmd = "Test-ScoopInstalled"; Alias = "Test-ScoopInstalled"; Desc = "检查 scoop 是否安装" }
    )
    
    foreach ($cmd in $commandList) {
        Write-Host ("  {0,-25} {1,-15} {2}" -f $cmd.Cmd, $cmd.Alias, $cmd.Desc) -ForegroundColor Green
    }
    
    Write-Host "`n=== Android 模块（懒加载）===" -ForegroundColor Cyan
    Write-Host ("  {0,-25} {1,-15} {2}" -f "命令", "别名", "说明") -ForegroundColor White
    Write-Host "  $('─' * 55)" -ForegroundColor DarkGray
    
    $moduleCommands = @(
        @{ Name = "Get-ApkInfo"; Alias = "apkinfo"; Desc = "获取 APK 信息" },
        @{ Name = "Get-ApkSignInfo"; Alias = "apksign"; Desc = "获取 APK 签名" },
        @{ Name = "Get-JarSignInfo"; Alias = "jarsign"; Desc = "获取 JAR 签名" },
        @{ Name = "Get-ApkLibs"; Alias = "apklibs"; Desc = "获取 APK 中的 so 文件" },
        @{ Name = "Get-ApkProtectInfo"; Alias = "apkprotect"; Desc = "查看加固信息" },
        @{ Name = "Get-AppObfuscInfo"; Alias = "appinfo"; Desc = "获取混淆信息" },
        @{ Name = "Get-DeviceApk"; Alias = "pullapk"; Desc = "从设备提取 APK" },
        @{ Name = "Decompile-Apk"; Alias = "decompile"; Desc = "反编译 APK" },
        @{ Name = "Recompile-Apk"; Alias = "recompile"; Desc = "重编译 APK" },
        @{ Name = "Sign-Apk"; Alias = "signapk"; Desc = "签名 APK" },
        @{ Name = "Test-RebuiltApk"; Alias = "testapk"; Desc = "重打包测试" },
        @{ Name = "Test-EmulatorApk"; Alias = "testemu"; Desc = "模拟器测试" },
        @{ Name = "Test-ApkLib"; Alias = "testlib"; Desc = "APK 安全检测" }
    )
    
    foreach ($cmd in $moduleCommands) {
        Write-Host ("  {0,-25} {1,-15} {2}" -f $cmd.Name, $cmd.Alias, $cmd.Desc) -ForegroundColor Magenta
    }
}

# ========== 别名管理 ==========

function Add-MyAlias {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Target
    )
    
    $aliasMap[$Name] = $Target
    Set-Alias -Name $Name -Value $Target -Scope Global
    Write-Host "✓ 已添加别名: $Name → $Target" -ForegroundColor Green
}

function Remove-MyAlias {
    param([Parameter(Mandatory)][string]$Name)
    
    if ($aliasMap.ContainsKey($Name)) {
        $aliasMap.Remove($Name)
        Remove-Item -Path "alias:$Name" -ErrorAction SilentlyContinue
        Write-Host "✓ 已删除别名: $Name" -ForegroundColor Green
    } else {
        Write-Host "✗ 未找到别名: $Name" -ForegroundColor Red
    }
}
