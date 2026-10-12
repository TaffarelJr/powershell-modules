#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Enter-GitHubActionsLogGroup 'Restoring packages' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Enter-GitHubActionsLogGroup prints exactly one line'
Assert-Equal -Expected '::group::Restoring packages' -Actual $lines[0] -Message 'The line is the group command, with the title as its data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'Step one', 'Step two' | Enter-GitHubActionsLogGroup }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two titles prints two separate lines'

exit (Complete-TestRun)
