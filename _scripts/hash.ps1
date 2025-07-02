
function Get-FileMD5Hash {
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )
    Get-FileHash -Algorithm MD5 $path
}

function Get-FileSHA1Hash {
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )
    Get-FileHash -Algorithm SHA1 $path
}

function Get-FileSHA256Hash {
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )
    Get-FileHash -Algorithm SHA256 $path
}

Set-Alias -Name md5sum -Value Get-FileMD5Hash -Scope Global
Set-Alias -Name sha1sum -Value Get-FileSHA1Hash -Scope Global
Set-Alias -Name sha256sum -Value Get-FileSHA256Hash -Scope Global
