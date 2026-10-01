#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - this file itself always runs non-interactively,
# so Wait-KeyPress genuinely has nobody to wait on here -
# a real (not simulated) check that it returns immediately
# instead of blocking on Console.ReadKey
$lines = Get-HostOutput { Wait-KeyPress }

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'Wait-KeyPress prints nothing when the host is not interactive'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a custom message is also suppressed the same way
$lines = Get-HostOutput { Wait-KeyPress -Message 'Custom message' }

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A custom -Message is also suppressed when not interactive'

exit (Complete-TestRun)
