# rust.ps1 - Rust 环境配置

# 国内镜像加速
$env:RUSTUP_DIST_SERVER = "https://rsproxy.cn"
$env:RUSTUP_UPDATE_ROOT = "https://rsproxy.cn/rustup"

# 添加 cargo bin 到 PATH
$cargoBin = "$env:USERPROFILE\.cargo\bin"
if (Test-Path $cargoBin) {
    Add-PathToEnv $cargoBin
}
