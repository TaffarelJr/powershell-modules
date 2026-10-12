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
# Arrange - a plain approval
$fake = New-FakeGitHubCli
try {
    # Act
    Submit-GitHubPullRequestReview -PullRequest 12 -Decision Approve -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'review', '12', '--approve', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'Approve becomes --approve, with no body'
    Assert-Equal -Expected 0 -Actual $call.Files.Count -Message 'No file is passed without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a change request with a body
$fake = New-FakeGitHubCli
try {
    # Act
    Submit-GitHubPullRequestReview -Decision RequestChanges -Body "Needs tests.`n`n- one`n"
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'review', '--request-changes', '--body-file', $file) -Actual $call.Arguments `
        -Message 'RequestChanges becomes --request-changes and the body is read from a file'
    Assert-Equal -Expected "Needs tests.`n`n- one`n" -Actual $call.Files[$file] -Message 'which holds the body exactly'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a comment
$fake = New-FakeGitHubCli
try {
    # Act
    Submit-GitHubPullRequestReview -PullRequest 5 -Decision Comment -Body 'Looks interesting'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'review', '5', '--comment', '--body-file', $file) -Actual $call.Arguments `
        -Message 'Comment becomes --comment'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with each decision and a body
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Submit-GitHubPullRequestReview -PullRequest 5 -Decision RequestChanges -Body 'Private text' -Repository 'o/r' `
            -WhatIf
        Submit-GitHubPullRequestReview -PullRequest 5 -Decision Approve -WhatIf
        Submit-GitHubPullRequestReview -PullRequest 5 -Decision Comment -Body 'Private text' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Request changes on pull request" on target "o/r pull request #5".'
        'What if: Performing the operation "Approve pull request" on target "pull request #5".'
        'What if: Performing the operation "Comment on pull request in a review" on target "pull request #5".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names the pull request and the decision, never the review text'
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
        @(1, 2) | Submit-GitHubPullRequestReview -Decision Approve -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Approve pull request" on target "pull request #1".'
        'What if: Performing the operation "Approve pull request" on target "pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped pull request is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is reviewed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with -Repository and no pull request
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Submit-GitHubPullRequestReview -Decision Approve -Repository 'o/r' -WhatIf
    } -MessageLike '-Repository o/r was given without a pull request, and gh needs one named along with --repo.*' `
        -Message 'The missing pull request is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
