#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a default is set
$fake = New-FakeGitHubCli -Output @('o/r')
try {
    # Act
    $default = Get-GitHubDefaultRepository
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'set-default', '--view') -Actual $call.Arguments `
        -Message 'gh is asked to show the default'
    Assert-Equal -Expected 'o/r' -Actual $default -Message 'The default repository is returned as a string'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - none is set, which gh says on standard error while succeeding
$fake = New-FakeGitHubCli -ErrorOutput @('X No default remote repository has been set.') -ExitCode 0
try {
    # Act
    $default = @(Get-GitHubDefaultRepository)

    # Assert
    Assert-Equal -Expected 0 -Actual $default.Count `
        -Message 'No default writes nothing - not $null, not an error, and not gh''s message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh cannot read it at all, as outside a git repository
$fake = New-FakeGitHubCli -ErrorOutput @('must be run from inside a git repository') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubDefaultRepository
    } -MessageLike '*Reading the default repository failed*must be run from inside a git repository*' `
        -Message 'A failure is not "none set": it throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
