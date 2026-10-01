#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Every named count, in the order each name was first added.
# A caller never touches this directly -
# Add-Tally/Get-Tally/Clear-Tally/Format-Tally are the only way in or out.
$script:Tallies = [ordered]@{}

# One isolated set of counters per -Key, created lazily on first use.
# Keeps two callers who both use a name like "passed" from adding
# to the same running count, without either of them knowing about the other.
$script:KeyedTallies = @{}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Add-Tally'
    'Clear-Tally'
    'Format-Tally'
    'Get-Tally'
    'Read-Tally'
)
