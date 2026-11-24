#Requires -Version 7.6

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Variable -Name UntaggedName -Value '(untagged)' -Option Constant -Scope Script

# The same text as each command's ValidatePattern, which cannot read a variable.
New-Variable -Name TagPattern -Option Constant -Scope Script -Value '^\S([^\r\n\u0085\p{Zl}\p{Zp}\u000B\u000C]*\S)?\z'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Add-Tally'
    'Clear-Tally'
    'Get-Tally'
)
