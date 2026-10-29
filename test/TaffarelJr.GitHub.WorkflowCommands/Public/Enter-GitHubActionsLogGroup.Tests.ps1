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
$lines = @(Get-WorkflowCommand { Enter-GitHubActionsLogGroup 'Restoring packages' })

# Assert
Assert-Equal -Expected @('::group::Restoring packages') -Actual $lines `
    -Message 'One line is written: the group command, with the title as its data segment'

#───────────────────────────────────────────────────────────────────────────────
# Act
$empty = @(Get-WorkflowCommand { Enter-GitHubActionsLogGroup '' })

# Assert
Assert-Equal -Expected @('::group::') -Actual $empty `
    -Message 'An empty title is allowed, as the runner accepts a group with none'

#───────────────────────────────────────────────────────────────────────────────
# Act - a title needing escaping
$escaped = @(Get-WorkflowCommand { Enter-GitHubActionsLogGroup "two`nlines :: 100%" })

# Assert
Assert-Equal -Expected @('::group::two%0Alines :: 100%25') -Actual $escaped `
    -Message 'The title is escaped as command data'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - groups do not nest, so several titles cannot be piped
Assert-Throws -ScriptBlock { 'one', 'two' | Enter-GitHubActionsLogGroup -Title 'x' } `
    -MessageLike '*does not take pipeline input*' `
    -Message 'Titles are not taken from the pipeline, as several would start groups that never end'

exit (Complete-TestRun)
