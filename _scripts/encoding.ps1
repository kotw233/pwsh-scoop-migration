
# Base64 encode/decode helper.
function ConvertTo-Base64String {
    param (
        [Parameter(Mandatory = $true)]
        [string]$content
    )
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($content)
    $encodedText = [Convert]::ToBase64String($bytes)
    Write-Host $encodedText
}

function ConvertFrom-Base64String {
    param (
        [Parameter(Mandatory = $true)]
        [string]$content
    )
    $decodedText = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($content))
    Write-Host $decodedText
}

Set-Alias -Name b64encode -Value ConvertTo-Base64String -Scope Global
Set-Alias -Name b64decode -Value ConvertFrom-Base64String -Scope Global
