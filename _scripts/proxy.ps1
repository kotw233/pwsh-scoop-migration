# proxy.ps1 - 代理开关

function Set-Proxy {
    $proxy = "http://127.0.0.1:10809"
    $Env:HTTP_PROXY = $proxy
    $Env:HTTPS_PROXY = $proxy
    Write-Host "✓ 代理已启用: $proxy" -ForegroundColor Green
}

function Unset-Proxy {
    $Env:HTTP_PROXY = ""
    $Env:HTTPS_PROXY = ""
    Write-Host "✗ 代理已禁用" -ForegroundColor Red
}


