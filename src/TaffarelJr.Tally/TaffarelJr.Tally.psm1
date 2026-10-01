#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Every named count, in the order each name was first added.
# A caller never touches this directly -
# Add-Tally/Get-Tally/Clear-Tally/Format-Tally are the only way in or out.
$script:Tallies = [ordered]@{}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Add-Tally'
    'Get-Tally'
    'Clear-Tally'
    'Format-Tally'
)
