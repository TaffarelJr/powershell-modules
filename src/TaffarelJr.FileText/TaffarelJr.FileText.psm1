#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Get-FileEncoding'
    'Get-LineEnding'
    'Read-TextFile'
    'Write-TextFile'
    'Update-FileToken'
    'Rename-Token'
)
