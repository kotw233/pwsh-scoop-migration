## Utils.

cls

if ($host.Name -eq "ConsoleHost") {
    Write-Host "Initializing..." -foregroundcolor DarkGray
    Write-Host "Now:" ([System.DateTime]::Now.toString()) -foregroundcolor DarkGray

    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\kali.omp.json" | Invoke-Expression
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

function Test-PathEx {
    param(
        [string]$path
    )
    # 验证路径非空且非空字符串
    if (-not $path -or $path -eq "") {
        return $false
    }

    # 执行测试
    try {
        Test-Path -Path $path
    }
    catch {
        return $false
    }
    return $true
}

function Add-PathToEnv {
    param (
        [Parameter(Mandatory = $true)]
        [string]$newPath
    )
    
    # 检查路径是否存在
    if (-not (Test-PathEx $newPath)) {
        return
    }
    
    # 检查路径是否已经存在
    $currentPaths = $Env:Path.Split(";") | Where-Object { $_.Trim().Length -ne 0 }
    if ($currentPaths -contains $newPath) {
        return
    }
    
    $Env:Path = ($currentPaths += $newPath) -join ";"
    
    Write-Host "✅ 环境变量已添加，仅当前会话有效" -ForegroundColor Green
}

function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Here's script entry.
if (Test-Administrator) {
    return
}

# Load Subscripts.
Get-ChildItem -Filter "*.ps1" -Path "$PSScriptRoot/_scripts" | ForEach-Object {
    Invoke-Expression -Command $(Get-Content $_.FullName -Raw)
}
