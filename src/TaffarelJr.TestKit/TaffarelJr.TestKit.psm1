#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Owned by Assert-That, read by Complete-TestRun.
# Not exposed to a caller - there is deliberately no Get-PassCount;
# a test file only ever needs the final tally Complete-TestRun renders,
# not the running total.
$script:PassCount = 0
$script:FailCount = 0

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Assert-That'
    'Assert-Equal'
    'Assert-Throws'
    'Complete-TestRun'
    'Get-HostOutput'
)
