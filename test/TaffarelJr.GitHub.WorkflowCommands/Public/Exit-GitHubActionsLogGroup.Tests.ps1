#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Exit-GitHubActionsLogGroup }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Exit-GitHubActionsLogGroup prints exactly one line'
Assert-Equal -Expected '::endgroup::' -Actual $lines[0] -Message 'The line is the bare endgroup command, with no data segment'

exit (Complete-TestRun)
