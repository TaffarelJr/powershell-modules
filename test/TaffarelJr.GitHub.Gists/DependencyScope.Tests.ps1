#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'A stand-in is a function of the global scope, which can only record a call in a global variable.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$testKit = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
$invocation = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1'
$core = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1'
$subject = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1'
Import-Module $testKit -Force
Import-Module $invocation -Force
Import-Module $core -Force
Import-Module $subject -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

function Set-GlobalShadow {
    <#
    .SYNOPSIS
        Defines, in the global scope, a stand-in for each named command that
        records its call in $global:ShadowCall instead of doing anything.
    .DESCRIPTION
        Not exported - a test-only fixture. A command of the same name that
        a module's own scope does not hold is found here first, which is how
        a later-loaded module or script can take the place of a dependency.
    .PARAMETER Name
        The commands to stand in for.
    .PARAMETER Output
        The text a stand-in returns, by command name; none for one left out.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Name,

        [hashtable]$Output = @{}
    )

    $global:ShadowCall = [System.Collections.Generic.List[string]]::new()
    foreach ($command in $Name) {
        $text = "`$global:ShadowCall.Add('$command')"
        if ($Output.ContainsKey($command)) {
            $text += "; '$($Output[$command])'"
        }

        Set-Item -LiteralPath "Function:\global:$command" -Value ([scriptblock]::Create($text))
    }
}

$shadowed = 'Invoke-GitHubCommand', 'Hide-UrlCredential'
$answers = @{ 'Hide-UrlCredential' = 'shadow' }
$expected = @('gist', 'rename', '--', 'abc123', 'a.txt', 'b.txt')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - stand-ins for a Core command and a ProcessInvocation command, defined in the global scope last
$fake = New-FakeGitHubCli
try {
    Set-GlobalShadow -Name $shadowed -Output $answers

    # Act
    Rename-GitHubGistFile -Id 'abc123' -OldName 'a.txt' -NewName 'b.txt'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCall) -Message 'No stand-in is called'
    Assert-Equal -Expected $expected -Actual $calls[0].Arguments `
        -Message 'The module calls the commands it imported, and Core reaches gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Core imported again, after the module, and the stand-ins defined after that
Import-Module $core -Force
$fake = New-FakeGitHubCli
try {
    Set-GlobalShadow -Name $shadowed -Output $answers

    # Act
    Rename-GitHubGistFile -Id 'abc123' -OldName 'a.txt' -NewName 'b.txt'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCall) `
        -Message 'No stand-in is called after Core is imported again'
    Assert-Equal -Expected $expected -Actual $calls[0].Arguments `
        -Message 'and the module still reaches gh through Core'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the module imported again too, and the stand-ins defined after that
Import-Module $subject -Force
$fake = New-FakeGitHubCli
try {
    Set-GlobalShadow -Name $shadowed -Output $answers

    # Act
    Rename-GitHubGistFile -Id 'abc123' -OldName 'a.txt' -NewName 'b.txt'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCall) `
        -Message 'No stand-in is called after the module is imported again'
    Assert-Equal -Expected $expected -Actual $calls[0].Arguments `
        -Message 'and it still reaches gh through Core'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a required module that is not loaded when the module's own file runs
Remove-Module 'TaffarelJr.GitHub.Core' -Force
$rootModule = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psm1'

# Act / Assert
Assert-Throws -ScriptBlock {
    Import-Module $rootModule -Force
} -MessageLike '*TaffarelJr.GitHub.Core must be loaded before TaffarelJr.GitHub.Gists.*' `
    -Message 'A required module that is not loaded is named in the failure'

exit (Complete-TestRun)
