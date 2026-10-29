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
    Open-GitHubIssue -Issue 12 -Comment 'Back open' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'reopen', '12', '--comment=Back open', '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The issue is positional and the comment is joined to its flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a comment that is exactly the end-of-options marker
$fake = New-FakeGitHubCli
try {
    # Act
    Open-GitHubIssue -Issue 12 -Comment '--' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'reopen', '12', '--comment=--', '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The comment is joined to its flag, so even -- stays the comment'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a comment given but blank
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Open-GitHubIssue -Issue 12 -Comment ' '
    } -MessageLike '-Comment is blank: give the comment''s text, or leave it out.' `
        -Message 'A blank comment is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Open-GitHubIssue -Issue 12 -Comment ''
    } -MessageLike '-Comment is blank: give the comment''s text, or leave it out.' -Message 'as is an empty one'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - issues from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Open-GitHubIssue
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped issue is reopened in its own call'
    Assert-Equal -Expected @('issue', 'reopen', '2') -Actual $calls[1].Arguments `
        -Message 'The second piped issue is reopened too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a comment
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Open-GitHubIssue -Issue 12 -Comment 'Secret text' -Repository 'o/r' -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Reopen issue" on target "o/r issue #12".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the issue and the change, never the comment'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and reopens nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank comment, and with a pull request
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Open-GitHubIssue -Issue 12 -Comment '' -WhatIf
    } -MessageLike '-Comment is blank: give the comment''s text, or leave it out.' `
        -Message '-WhatIf still refuses a blank comment'
    Assert-Throws -ScriptBlock {
        Open-GitHubIssue -Issue 'https://github.com/o/r/pull/3' -WhatIf
    } -MessageLike '*is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests*' `
        -Message 'and a pull request'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two issues piped under -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @('1', '2') | Open-GitHubIssue -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Reopen issue" on target "issue #1".'
        'What if: Performing the operation "Reopen issue" on target "issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped issue'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and reopens neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
