
function Proxy {
    $proxy = "http://127.0.0.1:10808"
    $Env:HTTP_PROXY = $proxy 
    $Env:HTTPS_PROXY = $proxy
    Write-Host "✅ 终端代理已启用（仅当前会话生效）：127.0.0.1:10808" -ForegroundColor Green
}

function unProxy {
    $Env:HTTP_PROXY = "" 
    $Env:HTTPS_PROXY = ""
    Write-Host "❌ 终端代理已禁用" -ForegroundColor Red
}