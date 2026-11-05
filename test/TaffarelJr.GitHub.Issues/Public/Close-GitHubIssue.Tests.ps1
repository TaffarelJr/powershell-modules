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
    Close-GitHubIssue -Issue 12 -Comment 'Fixed' -Reason completed -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'close', '12', '--comment=Fixed', '--reason', 'completed', '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The issue is positional and each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a reason in a casing other than gh's, which gh would take for
# completed
$fake = New-FakeGitHubCli
try {
    # Act
    Close-GitHubIssue -Issue 12 -Reason 'Not Planned'
    Close-GitHubIssue -Issue 13 -Reason 'DUPLICATE' -DuplicateOf 7
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('issue', 'close', '12', '--reason', 'not planned') -Actual $calls[0].Arguments `
        -Message '-Reason reaches gh lower-cased'
    $expected = @('issue', 'close', '13', '--reason', 'duplicate', '--duplicate-of', '7')
    Assert-Equal -Expected $expected -Actual $calls[1].Arguments -Message 'so a duplicate stays a duplicate'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the original given as a listed issue, and as a hashtable
$original = [PSCustomObject]@{ Number = 7; Url = 'https://github.com/o/r/issues/7' }
$fake = New-FakeGitHubCli
try {
    # Act
    Close-GitHubIssue -Issue 12 -DuplicateOf $original
    Close-GitHubIssue -Issue 13 -DuplicateOf @{ Number = 7 }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    $expected = @('issue', 'close', '12', '--duplicate-of', 'https://github.com/o/r/issues/7')
    Assert-Equal -Expected $expected -Actual $calls[0].Arguments `
        -Message '-DuplicateOf reads an object by its Url, not its text'
    Assert-Equal -Expected @('issue', 'close', '13', '--duplicate-of', '7') -Actual $calls[1].Arguments `
        -Message 'and a hashtable by its Number'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - originals that name no issue, and a comment given but blank
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Close-GitHubIssue -Issue 12 -DuplicateOf $null
    } -MessageLike '*An issue was given, but it is $null.*' `
        -Message 'A -DuplicateOf given as $null is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Close-GitHubIssue -Issue 12 -DuplicateOf 'https://github.com/o/r/pull/7'
    } -MessageLike '*is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests*' `
        -Message 'and so is a pull request'
    Assert-Throws -ScriptBlock {
        Close-GitHubIssue -Issue 12 -DuplicateOf @(7, 8)
    } -MessageLike 'Give one issue at a time, not a list of 2; call once per issue.' `
        -Message 'and several originals, without advice to pipe them'
    Assert-Throws -ScriptBlock {
        Close-GitHubIssue -Issue 12 -Comment ' '
    } -MessageLike '-Comment is blank: give the comment''s text, or leave it out.' `
        -Message 'A blank comment is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Close-GitHubIssue -Issue 12 -Comment ''
    } -MessageLike '-Comment is blank: give the comment''s text, or leave it out.' -Message 'as is an empty one'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a comment that is exactly the end-of-options marker
$fake = New-FakeGitHubCli
try {
    # Act
    Close-GitHubIssue -Issue 12 -Comment '--' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'close', '12', '--comment=--', '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The comment is joined to its flag, so it stays the comment'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - issues from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Close-GitHubIssue
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped issue is closed in its own call'
    Assert-Equal -Expected @('issue', 'close', '2') -Actual $calls[1].Arguments `
        -Message 'The second piped issue is closed too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every option
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Close-GitHubIssue -Issue 12 -Comment 'Secret text' -Reason duplicate -DuplicateOf 7 -Repository 'o/r' -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Close issue" on target "o/r issue #12".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the issue and the change, never the comment'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and closes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank comment, and with an issue from another
# repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Close-GitHubIssue -Issue 12 -Comment ' ' -WhatIf
    } -MessageLike '-Comment is blank: give the comment''s text, or leave it out.' `
        -Message '-WhatIf still refuses a blank comment'
    Assert-Throws -ScriptBlock {
        Close-GitHubIssue -Issue 'https://github.com/o/r/issues/1' -Repository 'o/other' -WhatIf
    } -MessageLike "*/issues/1' is in o/r, but -Repository names o/other: give one or the other." `
        -Message 'and an issue in another repository than -Repository'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two issues piped under -WhatIf, by number and by URL
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @('1', 'https://ghe.example.com/o/r/issues/2') | Close-GitHubIssue -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Close issue" on target "issue #1".'
        'What if: Performing the operation "Close issue" on target "ghe.example.com/o/r issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped issue'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and closes neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a credential in a repository URL, an issue URL, and a
# repository object's Url
$fake = New-FakeGitHubCli
$url = 'https://user:SENTINEL@github.com/o/r'
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Close-GitHubIssue -Issue 1 -Repository $url -WhatIf
        Close-GitHubIssue -Issue "$url/issues/2" -WhatIf
        [PSCustomObject]@{ Number = 3; Url = "$url/issues/3" } | Close-GitHubIssue -WhatIf
        Close-GitHubIssue -Issue 4 -Repository ([PSCustomObject]@{ Url = $url }) -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Close issue" on target "o/r issue #1".'
        'What if: Performing the operation "Close issue" on target "o/r issue #2".'
        'What if: Performing the operation "Close issue" on target "o/r issue #3".'
        'What if: Performing the operation "Close issue" on target "o/r issue #4".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the repository without the credential, however the repository was given'
    Assert-Equal -Expected 0 -Actual @($whatIf.Messages -match 'SENTINEL').Count -Message 'which no line holds'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and nothing is closed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
