#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - message only, no properties
$lines = Get-HostOutput { Write-GitHubActionsError 'build failed' }

# Assert
Assert-Equal -Expected '::error::build failed' -Actual $lines[0] -Message 'With no properties, no space or property list appears before the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - file and line
$located = Get-HostOutput { Write-GitHubActionsError -Message 'syntax error' -File 'main.ps1' -Line 7 -Col 3 }

# Assert
Assert-Equal -Expected '::error file=main.ps1,line=7,col=3::syntax error' -Actual $located[0] -Message 'File, line, and col are rendered ahead of the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'one', 'two' | Write-GitHubActionsError }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two strings prints two separate lines'

exit (Complete-TestRun)
