#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Read-Input'
    'Read-Secret'
    'Assert-Input'
    'Get-EnvironmentVariable'
    'Set-EnvironmentVariable'
    'Invoke-InputRetry'
    'Confirm-Input'
    'Confirm-Proceed'
    'Select-Choice'
    'Test-InteractiveHost'
    'Wait-KeyPress'
)
