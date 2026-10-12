#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-WorkflowCommand { Exit-GitHubActionsLogGroup })

# Assert
Assert-Equal -Expected @('::endgroup::') -Actual $lines `
    -Message 'One line is written: the bare endgroup command, with no data segment'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Exit-GitHubActionsLogGroup 'stray argument' } `
    -MessageLike '*positional parameter cannot be found*' `
    -Message 'A stray argument is refused rather than ignored'

exit (Complete-TestRun)
