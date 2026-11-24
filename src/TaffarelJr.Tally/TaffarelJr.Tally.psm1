#Requires -Version 7.6

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Variable -Name UntaggedName -Value '(untagged)' -Option Constant -Scope Script

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Add-Tally'
    'Clear-Tally'
    'Get-Tally'
)
