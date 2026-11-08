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
    Lock-GitHubIssue -Issue 12 -Reason Resolved -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'lock', '12', '--reason', 'resolved', '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The issue is positional and the reason becomes --reason, lower-cased as gh needs it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - issues from the pipeline, no reason
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Lock-GitHubIssue
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped issue is locked in its own call'
    Assert-Equal -Expected @('issue', 'lock', '2') -Actual $calls[1].Arguments -Message 'Without -Reason, none is sent'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a reason
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Lock-GitHubIssue -Issue 12 -Reason Resolved -Repository 'o/r' -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Lock issue (resolved)" on target "o/r issue #12".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the issue, the change and its reason'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and locks nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a pull request
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Lock-GitHubIssue -Issue 'https://github.com/o/r/pull/3' -WhatIf
    } -MessageLike '*is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests*' `
        -Message '-WhatIf still refuses a pull request'
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
        @('1', '2') | Lock-GitHubIssue -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Lock issue" on target "o/r issue #1".'
        'What if: Performing the operation "Lock issue" on target "o/r issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped issue'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and locks neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
