#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Write-Detail 'a continuation line' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Write-Detail prints exactly one line'
Assert-That -Condition ($lines[0] -like '*a continuation line*') -Message 'The line carries the given text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - blank text
$blank = Get-HostOutput { Write-Detail '' }

# Assert
Assert-That -Condition ($blank[0] -like '*(no message)*') -Message 'Blank text renders the placeholder instead of an empty line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'first', 'second' | Write-Detail }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two strings prints two separate lines'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - indent is deeper than a marker line at the same level
$detail = Get-HostOutput { Write-Detail 'x' }
$marker = Get-HostOutput { Write-Info 'x' }
$detailIndent = ([Regex]::Match($detail[0], '^ *')).Length
$markerIndent = ([Regex]::Match($marker[0], '^ *')).Length

# Assert
Assert-That -Condition ($detailIndent -gt $markerIndent) -Message 'Write-Detail sits further right than a marker line at the same ambient indent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Indent overrides the ambient indent too
$overridden = Get-HostOutput { Write-Detail -Text 'x' -Indent 4 }
$overriddenIndent = ([Regex]::Match($overridden[0], '^ *')).Length

# Assert
Assert-Equal -Expected ($detailIndent + 4) -Actual $overriddenIndent -Message '-Indent 4 adds four spaces on top of the default'

exit (Complete-TestRun)
