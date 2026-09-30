#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

# Arrange / Act - a single Write-Host call
$lines = Get-HostOutput { Write-Host 'one line' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'One Write-Host call captures as one element'
Assert-Equal -Expected 'one line' -Actual $lines[0] -Message 'The captured text matches exactly'

# Arrange / Act - multiple calls, in order
$multiLines = Get-HostOutput { Write-Host 'first'; Write-Host 'second'; Write-Host 'third' }

# Assert
Assert-Equal -Expected 3 -Actual $multiLines.Count -Message 'Three calls capture as three elements'
Assert-Equal -Expected 'first' -Actual $multiLines[0] -Message 'Order is preserved: first'
Assert-Equal -Expected 'second' -Actual $multiLines[1] -Message 'Order is preserved: second'
Assert-Equal -Expected 'third' -Actual $multiLines[2] -Message 'Order is preserved: third'

# Arrange / Act - nothing printed at all
$noLines = Get-HostOutput { $null = 1 + 1 }

# Assert
Assert-Equal -Expected 0 -Actual $noLines.Count -Message 'A script block that prints nothing returns an empty array'
Assert-That -Condition ($noLines -is [array]) -Message 'The empty result is still an array, not $null'

# Arrange / Act - genuine pipeline output alongside Write-Host is not captured
$mixed = Get-HostOutput { Write-Host 'printed'; 'returned' }

# Assert
Assert-Equal -Expected 1 -Actual $mixed.Count -Message 'Only the Write-Host call is captured, not the pipeline output'
Assert-Equal -Expected 'printed' -Actual $mixed[0] -Message 'The captured element is the Write-Host text, not the pipeline value'

exit (Complete-TestRun)
