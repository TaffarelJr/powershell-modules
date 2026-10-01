#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Assert-ExitCode'
    'Hide-MaskedValue'
    'Hide-UrlCredential'
    'Invoke-NativeCommand'
    'Invoke-NativeRead'
)
