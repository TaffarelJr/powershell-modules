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
    Close-GitHubPullRequest -PullRequest 12 -Comment 'Superseded' -DeleteBranch -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'close', '12', '--comment=Superseded', '--delete-branch', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message 'The pull request is positional and each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pull requests from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Close-GitHubPullRequest
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped pull request is closed in its own call'
    Assert-Equal -Expected @('pr', 'close', '2') -Actual $calls[1].Arguments `
        -Message 'The second piped pull request is closed too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a blank comment
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Close-GitHubPullRequest -PullRequest 12 -Comment ' '
    } -MessageLike '-Comment is blank: give the comment''s text, or leave it out.' `
        -Message 'A blank comment is refused, not dropped'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every option
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Close-GitHubPullRequest -PullRequest 12 -Comment 'Private text' -DeleteBranch -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Close pull request, deleting the head branch"' +
    ' on target "o/r pull request #12".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the pull request and the change, never the comment'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two pull requests piped in, one by URL
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        @('1', 'https://github.com/o/r/pull/2') | Close-GitHubPullRequest -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Close pull request" on target "pull request #1".'
        'What if: Performing the operation "Close pull request" on target "o/r pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped pull request is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is closed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a pull request in another repository than -Repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Close-GitHubPullRequest -PullRequest 'https://github.com/a/b/pull/1' -Repository 'c/d' -WhatIf
    } -MessageLike "'https://github.com/a/b/pull/1' is in a/b, but -Repository names c/d: give one or the other." `
        -Message 'The mismatch is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a credential in a repository URL, a pull request URL,
# and a repository object's Url
$fake = New-FakeGitHubCli
$url = 'https://user:SENTINEL@github.com/o/r'
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Close-GitHubPullRequest -PullRequest 1 -Repository $url -WhatIf
        Close-GitHubPullRequest -PullRequest "$url/pull/2" -WhatIf
        [PSCustomObject]@{ Number = 3; Url = "$url/pull/3" } | Close-GitHubPullRequest -WhatIf
        Close-GitHubPullRequest -PullRequest 4 -Repository ([PSCustomObject]@{ Url = $url }) -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Close pull request" on target "o/r pull request #1".'
        'What if: Performing the operation "Close pull request" on target "o/r pull request #2".'
        'What if: Performing the operation "Close pull request" on target "o/r pull request #3".'
        'What if: Performing the operation "Close pull request" on target "o/r pull request #4".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names the repository without the credential, however the repository was given'
    Assert-Equal -Expected 0 -Actual @($result.Messages -match 'SENTINEL').Count -Message 'which no line holds'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and nothing is closed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
