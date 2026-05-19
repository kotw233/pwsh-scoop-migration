#
# profile.ps1 - PowerShell 主配置文件
#
# 加载顺序:
#   1. Utils.ps1 (基础工具函数，其他脚本可能依赖)
#   2. scripts/*.ps1 (功能脚本，自动加载)
#   3. modules/*.ps1 (复杂模块，懒加载)
#

# ========== 基础设置 ==========

$ErrorActionPreference = "Stop"

# UTF-8 编码设置（必须在最前面）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$env:LC_ALL = "en_US.UTF-8"
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"

# ========== 目录定义 ==========

$BaseDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell"
$ScriptsDir = "$BaseDir\_scripts"
$ModulesDir = "$BaseDir\_modules"

# ========== 加载 Utils (必须最先加载) ==========

$utilsPath = Join-Path $ScriptsDir "Utils.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
}

# ========== 设置用户信息（starship 用） ==========

$env:STARSHIP_USER = $env:USERNAME
$script:isAdmin = Test-Administrator
if ($script:isAdmin) {
    $env:STARSHIP_IS_ADMIN = "1"
} else {
    $env:STARSHIP_IS_ADMIN = "0"
}

# ========== 加载 Scripts (自动加载，管理员模式跳过) ==========

if (-not $script:isAdmin) {
    if (Test-Path $ScriptsDir) {
        Get-ChildItem -Path $ScriptsDir -Filter "*.ps1" | Where-Object { $_.BaseName -ne "Utils" } | ForEach-Object {
            . $_.FullName
        }
    }

    # ========== 懒加载 Modules ==========
    if (Test-Path $ModulesDir) {
        Get-ChildItem -Path $ModulesDir -Filter "*.ps1" | Where-Object { $_.BaseName -notlike "Test-*" } | ForEach-Object {
            $modulePath = $_.FullName

            # 为脚本中每个函数创建懒加载包装
            $content = Get-Content $modulePath -Raw
            $functions = [regex]::Matches($content, 'function\s+(\S+)')
            foreach ($func in $functions) {
                $funcName = $func.Groups[1].Value
                $modulePathCopy = $modulePath
                $funcNameCopy = $funcName
                Set-Item -Path "function:$funcNameCopy" -Value {
                    Remove-Item -Path "function:$funcNameCopy" -ErrorAction SilentlyContinue
                    . $modulePathCopy
                    # 导出到全局作用域，确保后续调用可用
                    $func = Get-Item "function:$funcNameCopy" -ErrorAction SilentlyContinue
                    if ($func) { Set-Item -Path "global:function:$funcNameCopy" -Value $func }
                    & $funcNameCopy @args
                }.GetNewClosure()
            }

            # 别名也注册
            $aliases = [regex]::Matches($content, 'Set-Alias\s+-Name\s+(\S+)\s+-Value\s+(\S+)')
            foreach ($alias in $aliases) {
                $aliasName = $alias.Groups[1].Value
                $aliasValue = $alias.Groups[2].Value
                $modulePathCopy2 = $modulePath
                Set-Item -Path "function:$aliasName" -Value {
                    Remove-Item -Path "function:$aliasName" -ErrorAction SilentlyContinue
                    . $modulePathCopy2
                    # 导出别名到全局作用域
                    $alias = Get-Item "alias:$aliasName" -ErrorAction SilentlyContinue
                    if ($alias) { Set-Item -Path "global:alias:$aliasName" -Value $alias }
                    & $aliasValue @args
                }.GetNewClosure()
            }
        }
    }
}

# ========== 工具初始化（始终加载） ==========

if ($host.Name -eq "ConsoleHost") {
    # 仅普通模式显示初始化信息
    if (-not $script:isAdmin) {
        Write-Host "Initializing..." -ForegroundColor DarkGray
        Write-Host "Now:" ([System.DateTime]::Now.ToString()) -ForegroundColor DarkGray
    }

    # 设置 sudo 标记（starship 用来区分颜色）
    if ($script:isAdmin) {
        $env:STARSHIP_SUDO = "1"
    } else {
        $env:STARSHIP_SUDO = "0"
    }

    # starship 主题
    if (Test-CommandExists "starship") {
        Invoke-Expression (&starship init powershell)
    }

    # zoxide 智能 cd
    if (Test-CommandExists "zoxide") {
        Invoke-Expression (& { zoxide init powershell | Out-String })
    }

    # PSReadLine 配置
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # fzf 搜索集成
    if (Test-CommandExists "fzf") {
        $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
        $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
        $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border --info=inline'

        # Ctrl+R: fzf 搜索历史
        Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
            $line = $null; $cursor = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
            $history = Get-Content (Get-PSReadLineOption).HistorySavePath |
                Where-Object { $_ -match $line } |
                fzf --tac --no-sort --query "$line" --height 40% --layout=reverse --border
            if ($history) {
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($history)
            }
        }

        # Ctrl+T: fzf 搜索文件并插入路径
        Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock {
            $file = fd --type f --hidden --follow --exclude .git 2>$null |
                fzf --height 40% --layout=reverse --border
            if ($file) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($file)
            }
        }
    }
}

# WinGet CommandNotFound 提示
Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
