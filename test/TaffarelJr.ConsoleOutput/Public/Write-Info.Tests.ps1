#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Write-Info 'for your information' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Write-Info prints exactly one line'
Assert-That -Condition ($lines[0] -like '*ℹ️*') -Message 'The line carries the info marker'
Assert-That -Condition ($lines[0] -like '*for your information*') -Message 'The line carries the given text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - blank text
$blank = Get-HostOutput { Write-Info '' }

# Assert
Assert-That -Condition ($blank[0] -like '*(no message)*') -Message 'Blank text renders the placeholder instead of an empty line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'first', 'second' | Write-Info }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two strings prints two separate lines'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Indent overrides the ambient indent
$overridden = Get-HostOutput { Write-Info -Text 'x' -Indent 4 }
$leadingSpaces = ([Regex]::Match($overridden[0], '^ *')).Length

# Assert
Assert-Equal -Expected 6 -Actual $leadingSpaces -Message '-Indent 4 adds four spaces on top of the two-space base'

exit (Complete-TestRun)
