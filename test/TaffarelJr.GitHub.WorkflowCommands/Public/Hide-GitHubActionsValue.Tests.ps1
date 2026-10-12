#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Hide-GitHubActionsValue 's3cr3t-token' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Hide-GitHubActionsValue prints exactly one line'
Assert-Equal -Expected '::add-mask::s3cr3t-token' -Actual $lines[0] -Message 'The line is the add-mask command, with the value as its data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'secret-one', 'secret-two' | Hide-GitHubActionsValue }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two values prints two separate mask commands'

exit (Complete-TestRun)
