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
# Arrange - a squash merge with a commit message
$fake = New-FakeGitHubCli
try {
    # Act
    Merge-GitHubPullRequest -PullRequest 12 -Strategy squash -Subject 'feat: thing' -Body "Details`n`nMore`n" `
        -DeleteBranch `
        -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'pr', 'merge', '12', '--squash', '--subject=feat: thing', '--body-file', $file, '--delete-branch', '--repo',
            'o/r'
        ) `
        -Actual $call.Arguments `
        -Message 'The strategy becomes its gh flag and the body is read from a file'
    Assert-Equal -Expected "Details`n`nMore`n" -Actual $call.Files[$file] -Message 'which holds the body exactly'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty body
$fake = New-FakeGitHubCli
try {
    # Act
    Merge-GitHubPullRequest -PullRequest 12 -Strategy merge -Body ''
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'merge', '12', '--merge', '--body-file', $file) -Actual $call.Arguments `
        -Message 'An empty body is still a body'
    Assert-Equal -Expected '' -Actual $call.Files[$file] -Message 'and its file is empty'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current branch's pull request, with a guard on its head
$fake = New-FakeGitHubCli
try {
    # Act
    Merge-GitHubPullRequest -Strategy rebase -AuthorEmail 'a@b.c' -MatchHeadCommit 'abc123'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'merge', '--rebase', '--author-email=a@b.c', '--match-head-commit=abc123') `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, as one --flag=value token; without -PullRequest, the current branch''s is merged'
    Assert-Equal -Expected 0 -Actual $call.Files.Count -Message 'No file is passed without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the three alternatives to merging now
$fake = New-FakeGitHubCli
try {
    # Act
    Merge-GitHubPullRequest -PullRequest 1 -Strategy Squash -Auto
    Merge-GitHubPullRequest -PullRequest 2 -DisableAuto
    Merge-GitHubPullRequest -PullRequest 3 -Strategy merge -Admin
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('pr', 'merge', '1', '--squash', '--auto') -Actual $calls[0].Arguments `
        -Message '-Auto becomes --auto, and the strategy is lower-cased as gh''s flags are'
    Assert-Equal -Expected @('pr', 'merge', '2', '--disable-auto') -Actual $calls[1].Arguments `
        -Message '-DisableAuto becomes --disable-auto'
    Assert-Equal -Expected @('pr', 'merge', '3', '--merge', '--admin') -Actual $calls[2].Arguments `
        -Message '-Admin becomes --admin'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two of the alternatives together, which gh refuses
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 1 -Auto -Admin
    } -MessageLike '*Parameter set cannot be resolved*' -Message '-Auto and -Admin are refused together'
    Assert-Throws -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 1 -Auto -DisableAuto
    } -MessageLike '*Parameter set cannot be resolved*' -Message 'and so are -Auto and -DisableAuto'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are blank, which gh would take as no value or as an option
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 1 -Strategy squash -MatchHeadCommit ' '
    } -MessageLike '-MatchHeadCommit was given but is blank, so the merge would not be checked against any commit. Give the SHA, or leave -MatchHeadCommit off.' `
        -Message 'A blank head guard is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 1 -Strategy squash -Subject ''
    } -MessageLike '-Subject is blank: give the subject line, or leave it out.' -Message 'and so is a blank subject'
    Assert-Throws -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 1 -Strategy squash -AuthorEmail ' '
    } -MessageLike '-AuthorEmail is blank: give an email address, or leave it out.' -Message 'and a blank author email'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every option of a merge now
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 12 -Strategy Squash -Subject 'feat: thing' -Body 'Private text' `
            -AuthorEmail 'a@b.c' `
            -DeleteBranch `
            -MatchHeadCommit 'abc123' `
            -Repository 'o/r' `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Merge pull request (squash), deleting the head branch"' +
    ' on target "o/r pull request #12".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the pull request and the change, never the commit body'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with each alternative to merging now
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 1 -DisableAuto -WhatIf
        Merge-GitHubPullRequest -PullRequest 2 -Strategy merge -Admin -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Disable auto-merge" on target "pull request #1".'
        'What if: Performing the operation "Merge pull request with administrator privileges (merge)" on target' +
        ' "pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each alternative names its own change'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two pull requests piped in for auto-merge
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        @(1, 2) | Merge-GitHubPullRequest -Strategy squash -Auto -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Enable auto-merge (squash)" on target "pull request #1".'
        'What if: Performing the operation "Enable auto-merge (squash)" on target "pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped pull request is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is merged'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank subject
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Merge-GitHubPullRequest -PullRequest 1 -Strategy squash -Subject '' -WhatIf
    } -MessageLike '-Subject is blank: give the subject line, or leave it out.' `
        -Message 'A blank subject is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
