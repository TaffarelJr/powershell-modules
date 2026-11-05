#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block or child process the test hands it to, by scope.')]
param()

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
$lines = @(Get-WorkflowCommand {
        Invoke-GitHubActionsLogGroup -Title 'Build' -ScriptBlock { Write-GitHubActionsDebug 'inside' }
    })

# Assert
Assert-Equal -Expected @('::group::Build', '::debug::inside', '::endgroup::') -Actual $lines `
    -Message 'The block runs between the group''s start and end'

#───────────────────────────────────────────────────────────────────────────────
# Act - a block that throws
$thrown = @(Get-WorkflowCommand {
        Assert-Throws -ScriptBlock {
            Invoke-GitHubActionsLogGroup 'Failing' { throw 'step broke' }
        } -MessageLike 'step broke' -Message 'The block''s own error reaches the caller'
    })

# Assert
Assert-Equal -Expected @('::group::Failing', '::endgroup::') -Actual $thrown -Message 'and the group is still ended'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeLineWriter
$assigned = 'before'

# Act
Invoke-GitHubActionsLogGroup 'Scope' { $assigned = 'inside the block' }

# Assert
Assert-Equal -Expected 'inside the block' -Actual $assigned `
    -Message 'The block runs in the caller''s own scope, so its assignments are kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeLineWriter

# Act
$output = @(Invoke-GitHubActionsLogGroup 'Output' { 'one'; 'two' })

# Assert
Assert-Equal -Expected @('one', 'two') -Actual $output `
    -Message 'Whatever the block outputs is passed on, and nothing else'

#───────────────────────────────────────────────────────────────────────────────
# Act
$untitled = @(Get-WorkflowCommand { Invoke-GitHubActionsLogGroup '' { } })

# Assert
Assert-Equal -Expected @('::group::', '::endgroup::') -Actual $untitled -Message 'An empty title is allowed'

#───────────────────────────────────────────────────────────────────────────────
# Act
$outputTypes = @((Get-Command Invoke-GitHubActionsLogGroup).OutputType.Type.FullName)

# Assert
Assert-Equal -Expected @('System.Object') -Actual $outputTypes `
    -Message 'The declared output type is any object, as the block''s output is passed on whatever it is'

exit (Complete-TestRun)
