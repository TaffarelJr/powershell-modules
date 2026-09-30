#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Write-Doing 'building'; Write-Done }

# Assert
Assert-That -Condition ($lines[0] -like '*▶*building*...*') -Message 'Write-Doing opens the line with the doing marker and an ellipsis'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - anything printed in between closes the open line first,
# on its own line, instead of running on to the end of it
$interrupted = Get-HostOutput { Write-Doing 'building'; Write-Info 'aside' }

# Assert
Assert-Equal -Expected 3 -Actual $interrupted.Count -Message 'An interrupting writer closes the open line, then prints its own'
Assert-Equal -Expected '' -Actual $interrupted[1] -Message 'The closing line is empty - just ends the open "Doing" line'
Assert-That -Condition ($interrupted[2] -like '*aside*') -Message 'The interrupting message prints after the closed line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input:
# the second item closes the first item's still-open line
# before opening its own, same as any other writer
$piped = Get-HostOutput { 'first', 'second' | Write-Doing }

# Assert
Assert-Equal -Expected 3 -Actual $piped.Count -Message 'The second piped item closes the first, then opens its own'
Assert-Equal -Expected '' -Actual $piped[1] -Message 'The closing line between them is empty'
Assert-That -Condition ($piped[2] -like '*second*') -Message 'The second line opens with its own text'

exit (Complete-TestRun)
