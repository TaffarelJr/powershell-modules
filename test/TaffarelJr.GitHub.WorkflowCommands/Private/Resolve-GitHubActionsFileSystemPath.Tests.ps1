#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell and the process in different folders
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null

    # Act
    $resolved = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        & $module { Resolve-GitHubActionsFileSystemPath -Path 'missing/x.txt' -Subject 's' -Kind 'file' }
    }

    # Assert
    Assert-Equal -Expected (Join-Path $here 'missing' 'x.txt') -Actual $resolved `
        -Message 'A relative path is taken from PowerShell''s location, and need not exist'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Resolve-GitHubActionsFileSystemPath -Path 'Env:\PATH' -Subject "-Path is 'Env:\PATH'" -Kind 'folder' }
    } -MessageLike ("-Path is 'Env:\PATH', which resolves to a path on the Environment provider, not a folder; " +
        'give a full file-system path, or run from a file-system location.') `
        -Message 'A path on another provider throws, starting with the subject and naming the kind'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Resolve-GitHubActionsFileSystemPath -Path 'NoSuchDrive:\x' -Subject 'X is here' -Kind 'file' }
    } -MessageLike "X is here, which PowerShell cannot resolve: Cannot find drive.*'NoSuchDrive'*" `
        -Message 'A path PowerShell cannot resolve throws with the reason itself, not the .NET call wrapped around it'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
