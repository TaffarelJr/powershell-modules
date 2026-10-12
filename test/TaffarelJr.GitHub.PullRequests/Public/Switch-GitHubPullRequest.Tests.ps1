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
    Switch-GitHubPullRequest -PullRequest 12 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'checkout', '12', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The pull request is positional and the repository goes through --repo'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a branch of its own name, and every other option
$fake = New-FakeGitHubCli
try {
    # Act
    Switch-GitHubPullRequest -PullRequest 'feature' -Branch 'review' -Force -RecurseSubmodules -Worktree '../wt'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $worktree = [IO.Path]::GetFullPath('../wt', (Get-Location).ProviderPath)
    Assert-Equal `
        -Expected @(
            'pr', 'checkout', 'feature', '--branch=review', '--force', '--recurse-submodules', "--worktree=$worktree"
        ) `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -Worktree written with ~ and one relative to PowerShell's location, which gh would read wrongly
$folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "wt-$([Guid]::NewGuid())")
$elsewhere = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "wt-$([Guid]::NewGuid())")
$fake = New-FakeGitHubCli
try {
    # Act
    Use-SplitLocation -Location $folder.FullName -ProcessDirectory $elsewhere.FullName -ScriptBlock {
        Switch-GitHubPullRequest -PullRequest 3 -Worktree '~/wt'
        Switch-GitHubPullRequest -PullRequest 3 -Worktree 'work/wt'
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('pr', 'checkout', '3', "--worktree=$(Join-Path $HOME 'wt')") `
        -Actual $calls[0].Arguments `
        -Message 'A -Worktree with ~ is given to gh as the home folder it stands for, since gh expands no ~'
    Assert-Equal -Expected @('pr', 'checkout', '3', "--worktree=$(Join-Path $folder.FullName 'work' 'wt')") `
        -Actual $calls[1].Arguments `
        -Message 'and a relative -Worktree as the full path under PowerShell''s location, not the process''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if line for a -Worktree written with ~
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock { Switch-GitHubPullRequest -PullRequest 3 -Worktree '~/wt' -WhatIf }

    # Assert
    $expected = 'What if: Performing the operation "Check out pull request #3 into a new worktree"' +
    " on target `"$(Join-Path $HOME 'wt')`"."
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the folder gh would be given, with ~ resolved'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a detached checkout
$fake = New-FakeGitHubCli
try {
    # Act
    Switch-GitHubPullRequest -PullRequest 3 -Detach
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'checkout', '3', '--detach') -Actual $call.Arguments `
        -Message '-Detach becomes --detach'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a detached checkout with a branch name, which gh would ignore, and
# a blank branch name
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Switch-GitHubPullRequest -PullRequest 3 -Detach -Branch 'review'
    } -MessageLike '-Branch and -Detach cannot be used together: a detached HEAD is on no branch. Give only one.' `
        -Message '-Detach and -Branch are refused together, with a sentence naming the pair'
    Assert-Throws -ScriptBlock {
        Switch-GitHubPullRequest -PullRequest 3 -Branch ' '
    } -MessageLike '-Branch is blank: give a branch name, or leave it out.' `
        -Message 'A blank branch name is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Switch-GitHubPullRequest -PullRequest 3 -Worktree ''
    } -MessageLike '-Worktree is blank: give the worktree''s path, or leave it out.' `
        -Message 'and so is a blank worktree path'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a branch, a worktree, and every other option
$fake = New-FakeGitHubCli
$worktree = [IO.Path]::GetFullPath('../wt', (Get-Location).ProviderPath)
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Switch-GitHubPullRequest -PullRequest 12 -Branch 'review' -Force -RecurseSubmodules -Worktree '../wt' `
            -Repository 'o/r' `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Check out o/r pull request #12 as branch review into a new' +
    ' worktree, resetting that branch if it exists and discarding uncommitted changes to tracked files,' +
    " updating every submodule`" on target `"$worktree`"."
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the worktree by its full path, what it would check out there, and each option'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two pull requests piped in, detached, in the current checkout
$fake = New-FakeGitHubCli
$here = (Get-Location).ProviderPath
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        @(1, 2) | Switch-GitHubPullRequest -Detach -WhatIf
    }

    # Assert
    $expected = @(
        "What if: Performing the operation `"Check out pull request #1 with a detached HEAD`" on target `"$here`"."
        "What if: Performing the operation `"Check out pull request #2 with a detached HEAD`" on target `"$here`"."
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped pull request is named on its own, and the target is the current location'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is checked out'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with -Branch and -Detach together
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Switch-GitHubPullRequest -PullRequest 12 -Branch 'review' -Detach -WhatIf
    } -MessageLike '-Branch and -Detach cannot be used together: a detached HEAD is on no branch. Give only one.' `
        -Message 'The pair is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
