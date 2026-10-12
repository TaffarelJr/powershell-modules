#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$processManifest = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1'
$coreManifest = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1'
$moduleManifest = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1'
Import-Module $processManifest -Force
Import-Module $coreManifest -Force
Import-Module $moduleManifest -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# A function of the same name, defined in the global scope after every import, shadows a command the module
# reaches only through the global scope. Each stands in for one the module calls and records that it was called.
$shadowed = [System.Collections.Generic.List[string]]::new()
$installShadows = {
    foreach ($name in 'Invoke-GitHubCommand', 'Resolve-GitHubRepositoryArgument') {
        $recorder = { $shadowed.Add($name) }.GetNewClosure()
        Set-Item -Path "Function:\global:$name" -Value $recorder
    }
}
$expectedCall = @('run', 'cancel', '12', '--repo', 'o/r')

$fake = New-FakeGitHubCli
try {
    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - the shadows come after every module is loaded
    & $installShadows

    # Act
    Stop-GitHubWorkflowRun -RunId 12 -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($shadowed) `
        -Message 'A global function of the same name never stands in for a Core command'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'so Core''s Invoke-GitHubCommand runs gh once'
    Assert-Equal -Expected $expectedCall -Actual $calls[0].Arguments -Message 'with the arguments the module built'

    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - the module imported again with -Force, then the shadows put back
    Import-Module $moduleManifest -Force
    & $installShadows

    # Act
    Stop-GitHubWorkflowRun -RunId 12 -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($shadowed) -Message 'The module imported again still ignores them'
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'and calls the real command'

    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - Core imported again with -Force, then the shadows put back
    Import-Module $coreManifest -Force
    & $installShadows

    # Act
    Stop-GitHubWorkflowRun -RunId 12 -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($shadowed) `
        -Message 'The module still ignores them after Core is imported again'
    Assert-Equal -Expected 3 -Actual $calls.Count -Message 'and still calls the command it imported'
    Assert-Equal -Expected $expectedCall -Actual $calls[2].Arguments -Message 'with the same arguments'

    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - the root module's file imported on its own, with Core unloaded
    $rootModule = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psm1'
    Remove-Module -Name 'TaffarelJr.GitHub.Workflows', 'TaffarelJr.GitHub.Core' -Force

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Import-Module $rootModule -Force
    } -MessageLike 'TaffarelJr.GitHub.Core must be loaded before TaffarelJr.GitHub.Workflows.' `
        -Message 'A module imported without Core loaded says Core must be loaded first'

    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - Core loaded again, ProcessInvocation not
    Import-Module $coreManifest -Force
    Remove-Module -Name 'TaffarelJr.ProcessInvocation' -Force

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Import-Module $rootModule -Force
    } -MessageLike 'TaffarelJr.ProcessInvocation must be loaded before TaffarelJr.GitHub.Workflows.' `
        -Message 'and one imported without ProcessInvocation loaded says so'
}
finally {
    foreach ($name in 'Invoke-GitHubCommand', 'Resolve-GitHubRepositoryArgument') {
        Remove-Item -Path "Function:\global:$name" -ErrorAction SilentlyContinue
    }

    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
