#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - message only, no properties
$lines = Get-HostOutput { Write-GitHubActionsWarning 'falling back to the cached value' }

# Assert
Assert-Equal -Expected '::warning::falling back to the cached value' -Actual $lines[0] -Message 'With no properties, no space or property list appears before the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - file and line
$located = Get-HostOutput { Write-GitHubActionsWarning -Message 'unused variable' -File 'build.ps1' -Line 42 }

# Assert
Assert-Equal -Expected '::warning file=build.ps1,line=42::unused variable' -Actual $located[0] -Message 'File and line are rendered ahead of the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'one', 'two' | Write-GitHubActionsWarning }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two strings prints two separate lines'

exit (Complete-TestRun)
