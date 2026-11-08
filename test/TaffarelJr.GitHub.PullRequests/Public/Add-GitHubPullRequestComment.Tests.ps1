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
# Arrange - a new comment
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubPullRequestComment -PullRequest 12 -Body "Hi`r`nthere – ünïcode`n" -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'comment', '12', '--body-file', $file, '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The body is read from a file'
    Assert-Equal -Expected "Hi`r`nthere – ünïcode`n" -Actual $call.Files[$file] `
        -Message 'which holds the body exactly, line endings and all'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $file) -Message 'The file is gone afterwards'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - editing the last comment, creating one if there is none
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubPullRequestComment -PullRequest 3 -Body 'Updated' -EditLast -CreateIfNone
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'comment', '3', '--body-file', $file, '--edit-last', '--create-if-none') `
        -Actual $call.Arguments `
        -Message '-EditLast and -CreateIfNone become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current branch's pull request, which gh cannot comment on
$fake = New-FakeGitHubCli -ErrorOutput @('no pull requests found for branch "main"') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubPullRequestComment -Body 'x'
    } -MessageLike "Commenting on the current branch's pull request failed*no pull requests found*" `
        -Message 'A failure names the pull request it was about'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -CreateIfNone alone
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubPullRequestComment -PullRequest 3 -Body 'x' -CreateIfNone
    } -MessageLike '-CreateIfNone works only with -EditLast: it adds a comment when there is no last one to edit. Give -EditLast too, or leave -CreateIfNone off.' `
        -Message '-CreateIfNone without -EditLast is refused, as gh refuses it'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a comment of nothing but white space, and an empty one
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubPullRequestComment -PullRequest 3 -Body " `n "
    } -MessageLike '-Body is blank, and GitHub refuses an empty comment. Give the text.' `
        -Message 'A blank comment is refused before gh, which GitHub would refuse'
    Assert-Throws -ScriptBlock {
        Add-GitHubPullRequestComment -PullRequest 3 -Body ''
    } -MessageLike '-Body is blank, and GitHub refuses an empty comment. Give the text.' `
        -Message 'and so is an empty one, with the same sentence'
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
        Add-GitHubPullRequestComment -PullRequest 7 -Body 'Private text' -EditLast -CreateIfNone `
            -Repository 'o/r' `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Edit last comment, or add one"' +
    ' on target "o/r pull request #7".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the pull request and the change, never the comment'
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
        @(1, 2) | Add-GitHubPullRequestComment -Body 'Private text' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Add comment" on target "pull request #1".'
        'What if: Performing the operation "Add comment" on target "pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped pull request is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is commented on'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank comment
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubPullRequestComment -PullRequest 7 -Body ' ' -WhatIf
    } -MessageLike '-Body is blank, and GitHub refuses an empty comment. Give the text.' `
        -Message 'A blank comment is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
