#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Owned by Assert-That, read by Complete-TestRun.
# Not exposed to a caller - there is deliberately no Get-PassCount;
# a test file only ever needs the final tally Complete-TestRun renders,
# not the running total.
#
# Private rather than kept in TaffarelJr.Tally, even with Tally's -Key:
# these counts belong to one test file's own run and are read back only
# by that same file's Complete-TestRun call, so there is nothing to share
# in the first place. An earlier version did route them through Tally's
# unkeyed counters, which collided with test files that use Tally for
# their own domain testing (like Tally's own tests) and silently produced
# wrong counts.
$script:PassCount = 0
$script:FailCount = 0

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Assert-Equal'
    'Assert-That'
    'Assert-Throws'
    'Complete-TestRun'
    'Get-HostOutput'
)
