#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubIssuesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubIssue -Issue 12 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'delete', '12', '--yes', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The issue is deleted without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - issues from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Remove-GitHubIssue
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped issue is deleted in its own call'
    Assert-Equal -Expected @('issue', 'delete', '2', '--yes') -Actual $calls[1].Arguments `
        -Message 'The second piped issue is deleted too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a repository
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubIssue -Issue 12 -Repository 'o/r' -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Delete issue" on target "o/r issue #12".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the issue and the change'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and deletes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with an issue from another repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubIssue -Issue 'https://github.com/o/r/issues/1' -Repository 'o/other' -WhatIf
    } -MessageLike "*/issues/1' is in o/r, but -Repository names o/other: give one or the other." `
        -Message '-WhatIf still refuses an issue in another repository than -Repository'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two issues piped under -WhatIf, one a listed issue
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        $listed = [PSCustomObject]@{
            Number = 2
            Url    = 'https://github.com/o/r/issues/2'
        }
        @('1', $listed) | Remove-GitHubIssue -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete issue" on target "issue #1".'
        'What if: Performing the operation "Delete issue" on target "o/r issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped issue'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and deletes neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
