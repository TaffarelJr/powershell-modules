#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force

# Arrange / Act - a name tallied for the first time starts from zero
Add-Tally -Name 'passed'

# Assert
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'passed') -Message 'A first Add-Tally call with no -Amount adds one'

# Act - a second call on the same name accumulates rather than resetting
Add-Tally -Name 'passed'

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'passed') -Message 'A second Add-Tally call on the same name accumulates'

# Act - an explicit -Amount adds that many at once
Add-Tally -Name 'failed' -Amount 3

# Assert
Assert-Equal -Expected 3 -Actual (Get-Tally -Name 'failed') -Message 'Add-Tally -Amount adds that many at once'

# Act - a negative -Amount decrements,
# since the module enforces no meaning on the count
Add-Tally -Name 'failed' -Amount -1

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'failed') -Message 'A negative -Amount decrements the tally'

exit (Complete-TestRun)
