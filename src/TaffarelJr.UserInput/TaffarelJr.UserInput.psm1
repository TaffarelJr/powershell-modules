#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Assert-Input'
    'Confirm-Input'
    'Confirm-Proceed'
    'Get-EnvironmentVariable'
    'Invoke-InputRetry'
    'Read-Input'
    'Read-Secret'
    'Select-Choice'
    'Set-EnvironmentVariable'
    'Test-InteractiveHost'
    'Wait-KeyPress'
)
