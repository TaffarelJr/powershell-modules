#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Lock-GitHubPullRequest -PullRequest 12 -Reason resolved -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'lock', '12', '--reason', 'resolved', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The pull request is positional and the reason becomes --reason'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a reason written in another case
$fake = New-FakeGitHubCli
try {
    # Act
    Lock-GitHubPullRequest -PullRequest 12 -Reason Too_Heated
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'lock', '12', '--reason', 'too_heated') -Actual $call.Arguments `
        -Message 'The reason is lower-cased, as gh refuses any other case'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pull requests from the pipeline, no reason
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Lock-GitHubPullRequest
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped pull request is locked in its own call'
    Assert-Equal -Expected @('pr', 'lock', '2') -Actual $calls[1].Arguments -Message 'Without -Reason, none is sent'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a reason
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Lock-GitHubPullRequest -PullRequest 3 -Reason Resolved -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Lock pull request (resolved)" on target "o/r pull request #3".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages -Message '-WhatIf names the pull request and the change'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two pull requests piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        @(1, 2) | Lock-GitHubPullRequest -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Lock pull request" on target "pull request #1".'
        'What if: Performing the operation "Lock pull request" on target "pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped pull request is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is locked'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a branch name
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Lock-GitHubPullRequest -PullRequest 'feature' -WhatIf
    } -MessageLike "'feature' is not a pull request: give its number or URL, as gh takes no branch name here." `
        -Message 'A branch name is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
