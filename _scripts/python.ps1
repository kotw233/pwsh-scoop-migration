# python.ps1 - Python 环境配置

# uv 包管理器路径
$uvBin = "$env:USERPROFILE\.local\bin"
if (Test-Path $uvBin) {
    Add-PathToEnv $uvBin
}

# pyenv-win 路径（如果安装）
$pyenvBin = "$env:USERPROFILE\pyenv-win\bin"
if (Test-Path $pyenvBin) {
    Add-PathToEnv $pyenvBin
}
