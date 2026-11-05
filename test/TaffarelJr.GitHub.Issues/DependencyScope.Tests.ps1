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
$subject = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1'
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

$shadowed = 'Resolve-GitHubRepositoryArgument', 'Resolve-GitHubItemReference', 'Invoke-GitHubCommand'
$answers = @{ 'Resolve-GitHubItemReference' = '12' }
$expected = @('issue', 'close', '12', '--repo', 'o/r')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - stand-ins for three of Core's commands, defined in the global scope after every import
$fake = New-FakeGitHubCli
try {
    Set-GlobalShadow -Name $shadowed -Output $answers

    # Act
    Close-GitHubIssue -Issue 12 -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCall) -Message 'No stand-in is called'
    Assert-Equal -Expected $expected -Actual $calls[0].Arguments `
        -Message 'The module calls the Core commands it imported, and Core reaches gh'
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
    Close-GitHubIssue -Issue 12 -Repository 'o/r'
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
    Close-GitHubIssue -Issue 12 -Repository 'o/r'
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
# Arrange - a stand-in for a command of ProcessInvocation, the other required module, which New-GitHubIssue calls
$url = 'https://github.com/o/r/issues/9'
$fake = New-FakeGitHubCli -Output $url
try {
    Set-GlobalShadow -Name 'Hide-UrlCredential' -Output @{ 'Hide-UrlCredential' = 'shadow' }

    # Act
    $created = New-GitHubIssue -Title 'A title' -Body 'A body' -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCall) `
        -Message 'The stand-in for ProcessInvocation is not called'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'and the issue is created through gh'
    Assert-Equal -Expected $url -Actual $created -Message 'and its URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a required module that is not loaded when the module's own file runs
Remove-Module 'TaffarelJr.GitHub.Core' -Force
$rootModule = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psm1'

# Act / Assert
Assert-Throws -ScriptBlock {
    Import-Module $rootModule -Force
} -MessageLike '*TaffarelJr.GitHub.Core must be loaded before TaffarelJr.GitHub.Issues.*' `
    -Message 'A required module that is not loaded is named in the failure'

exit (Complete-TestRun)
