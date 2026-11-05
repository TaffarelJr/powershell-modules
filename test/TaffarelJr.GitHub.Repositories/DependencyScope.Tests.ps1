#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The command stand-ins are global functions and record into a global variable.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$global:ShadowCalls = [Collections.Generic.List[string]]::new()
$fromModule = '* from TaffarelJr.GitHub.Repositories'
$fake = New-FakeGitHubCli
try {
    # A function of the same name, defined in the global scope after every import, is found ahead of a module's
    # command by anything that resolves through the global scope.
    function global:Invoke-GitHubCommand {
        $caller = (Get-PSCallStack)[1].InvocationInfo.MyCommand
        $global:ShadowCalls.Add("Invoke-GitHubCommand from $($caller.ModuleName)")
    }
    function global:Hide-UrlCredential {
        param($Text)

        $caller = (Get-PSCallStack)[1].InvocationInfo.MyCommand
        $global:ShadowCalls.Add("Hide-UrlCredential from $($caller.ModuleName)")
        $Text
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the shadows really are what a caller in the global scope reaches
    Invoke-GitHubCommand
    $null = Hide-UrlCredential -Text 'x'
    $reached = @($global:ShadowCalls | ForEach-Object { ($_ -split ' from ')[0] })
    $global:ShadowCalls.Clear()

    # Assert
    Assert-Equal -Expected @('Invoke-GitHubCommand', 'Hide-UrlCredential') -Actual $reached `
        -Message 'A global caller reaches the shadow functions, so they stand in front of the real commands'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a function that runs gh, which it reaches through TaffarelJr.GitHub.Core
    Remove-GitHubRepository -Repository 'o/r'
    $sent = @(Get-FakeGitHubCall -Fixture $fake | ForEach-Object { $_.Arguments -join ' ' })

    # Assert
    Assert-Equal -Expected @('repo delete o/r --yes') -Actual $sent `
        -Message 'The module still runs the real Invoke-GitHubCommand of TaffarelJr.GitHub.Core'
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls | Where-Object { $_ -like $fromModule }) `
        -Message 'and never the same-named function of the global scope'

    #───────────────────────────────────────────────────────────────────────────
    # Act - functions that name their target with TaffarelJr.ProcessInvocation's Hide-UrlCredential
    $global:ShadowCalls.Clear()
    Remove-GitHubLabel -Name 'bug' -Repository 'o/r' -WhatIf
    Add-GitHubDeployKey -KeyFile $PSCommandPath -Repository 'o/r' -WhatIf

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls | Where-Object { $_ -like $fromModule }) `
        -Message 'The module still runs the real Hide-UrlCredential of TaffarelJr.ProcessInvocation'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a dependency that is not loaded, so there is nothing to import it from
    $rootModule = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psm1'
    Remove-Module -Name TaffarelJr.GitHub.Repositories, TaffarelJr.GitHub.Core -Force

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Import-Module $rootModule -Force
    } -MessageLike 'TaffarelJr.GitHub.Core must be loaded before TaffarelJr.GitHub.Repositories.' `
        -Message 'Importing the module without TaffarelJr.GitHub.Core loaded fails, naming it'

    # Arrange
    Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
    Remove-Module -Name TaffarelJr.ProcessInvocation -Force

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Import-Module $rootModule -Force
    } -MessageLike 'TaffarelJr.ProcessInvocation must be loaded before TaffarelJr.GitHub.Repositories.' `
        -Message 'and without TaffarelJr.ProcessInvocation loaded it fails, naming that one'
}
finally {
    Remove-Item -LiteralPath Function:\global:Invoke-GitHubCommand, Function:\global:Hide-UrlCredential
    Remove-Variable -Name ShadowCalls -Scope Global
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
