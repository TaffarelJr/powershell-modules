#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Write-GitHubActionsDebug 'checked out at main' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Write-GitHubActionsDebug prints exactly one line'
Assert-Equal -Expected '::debug::checked out at main' -Actual $lines[0] -Message 'The line is the debug command, with the message as its data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'first', 'second' | Write-GitHubActionsDebug }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two strings prints two separate lines'
Assert-Equal -Expected '::debug::first' -Actual $piped[0] -Message 'The first piped line carries "first"'
Assert-Equal -Expected '::debug::second' -Actual $piped[1] -Message 'The second piped line carries "second"'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a message needing escaping
$escaped = Get-HostOutput { Write-GitHubActionsDebug "100%`nfree" }

# Assert
Assert-Equal -Expected '::debug::100%25%0Afree' -Actual $escaped[0] -Message 'The message is escaped before being written'

exit (Complete-TestRun)
