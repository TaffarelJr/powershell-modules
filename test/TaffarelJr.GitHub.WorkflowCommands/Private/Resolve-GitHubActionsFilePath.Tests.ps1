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
    # Arrange
    $path = New-CommandFile -Variable 'GITHUB_OUTPUT' -Directory $sandbox

    # Act
    $resolved = & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_OUTPUT' }

    # Assert
    Assert-Equal -Expected $path -Actual $resolved -Message 'A full path to an existing file is returned as it is'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative path, with PowerShell and the process in different
    # folders and a file of that name in each
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null
    $hereFile = New-CommandFile -Variable 'GITHUB_ENV' -Directory $here -Name 'env.txt'
    $null = New-CommandFile -Variable 'GITHUB_ENV' -Directory $there -Name 'env.txt'
    $env:GITHUB_ENV = 'env.txt'

    # Act
    $relative = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_ENV' }
    }

    # Assert
    Assert-Equal -Expected $hereFile -Actual $relative `
        -Message 'A relative path is taken from PowerShell''s location, not the process''s, and made full'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Remove-Item Env:\GITHUB_STATE -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_STATE' }
    } -MessageLike '*GITHUB_STATE is not set - this must run inside a GitHub Actions step*' `
        -Message 'An unset variable throws naming it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative path given while PowerShell is in the environment
    # provider
    $env:GITHUB_PATH = 'path.txt'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Push-Location -LiteralPath 'Env:\'
        try {
            & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_PATH' }
        }
        finally {
            Pop-Location
        }
    } -MessageLike "*GITHUB_PATH is 'path.txt', which resolves to a path on the Environment provider*" `
        -Message 'A path that resolves outside the file system is refused, naming the variable and its provider'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_PATH = 'Env:\PATH'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_PATH' }
    } -MessageLike "*GITHUB_PATH is 'Env:\PATH', which resolves to a path on the Environment provider*" `
        -Message 'as is one on another provider''s drive'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_OUTPUT = 'NoSuchDrive:\output.txt'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_OUTPUT' }
    } -MessageLike "*GITHUB_OUTPUT is 'NoSuchDrive:\output.txt', which PowerShell cannot resolve*NoSuchDrive*" `
        -Message 'A path on a drive that does not exist throws naming the variable'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $missing = Join-Path $sandbox 'missing.txt'
    $env:GITHUB_STEP_SUMMARY = $missing

    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_STEP_SUMMARY' }
    } -MessageLike "*GITHUB_STEP_SUMMARY points at '$missing', which is not a file*" `
        -Message 'A missing file throws naming the variable and the path, rather than being created'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_STEP_SUMMARY = $sandbox

    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Resolve-GitHubActionsFilePath -Variable 'GITHUB_STEP_SUMMARY' }
    } -MessageLike "*GITHUB_STEP_SUMMARY points at '$sandbox', which is not a file*" -Message 'as does a folder'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
