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
    Update-GitHubPullRequestBranch -PullRequest 12 -Rebase -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'update-branch', '12', '--rebase', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The pull request is positional and -Rebase becomes --rebase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current branch's pull request, merged
$fake = New-FakeGitHubCli
try {
    # Act
    Update-GitHubPullRequestBranch
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'update-branch') -Actual $call.Arguments `
        -Message 'Without options, the current branch''s pull request is updated by merge'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with -Rebase, and with the current branch's pull request
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Update-GitHubPullRequestBranch -PullRequest 9 -Rebase -Repository 'o/r' -WhatIf
        Update-GitHubPullRequestBranch -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Rebase the head branch onto the base branch" on target' +
        ' "o/r pull request #9".'
        'What if: Performing the operation "Merge the base branch into the head branch" on target' +
        ' "the current branch''s pull request".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message '-WhatIf names the pull request and the change'
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
        @(1, 2) | Update-GitHubPullRequestBranch -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Merge the base branch into the head branch" on target "pull request #1".'
        'What if: Performing the operation "Merge the base branch into the head branch" on target "pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped pull request is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is updated'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a pull request given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Update-GitHubPullRequestBranch -PullRequest $null -WhatIf
    } -MessageLike 'A pull request was given, but it is $null - leave it out to use the current branch*' `
        -Message 'A $null pull request is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
