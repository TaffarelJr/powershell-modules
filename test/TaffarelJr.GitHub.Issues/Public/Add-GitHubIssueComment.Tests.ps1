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
# Arrange - a new comment
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubIssueComment -Issue 12 -Body "Hi`nthere" -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    $expected = @('issue', 'comment', '12', '--body-file', $file.Path, '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments -Message 'The comment is read from a file'
    Assert-Equal -Expected "Hi`nthere" -Actual $file.Text -Message 'which holds the comment as given'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $file.Path) `
        -Message 'The file is gone once gh returns'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - comments that a transport to gh could alter
foreach ($case in Get-IssueTextCase) {
    $fake = New-FakeGitHubCli
    try {
        # Act
        Add-GitHubIssueComment -Issue 12 -Body $case.Text
        $file = Get-IssueTextFile -Call @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        Assert-Equal -Expected $case.Text -Actual $file.Text -Message "A comment reaches gh exactly: $($case.Name)"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - editing the last comment, creating one if there is none
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubIssueComment -Issue 12 -Body 'Updated' -EditLast -CreateIfNone
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    $expected = @('issue', 'comment', '12', '--body-file', $file.Path, '--edit-last', '--create-if-none')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message '-EditLast and -CreateIfNone become their gh flags, after the file as for a pull request'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - creating one if there is none, without editing the last one, and a
# blank comment
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubIssueComment -Issue 12 -Body 'x' -CreateIfNone
    } -MessageLike '-CreateIfNone works only with -EditLast: it adds a comment when there is no last one to edit. Give -EditLast too, or leave -CreateIfNone off.' `
        -Message '-CreateIfNone alone is refused, as gh refuses it'
    Assert-Throws -ScriptBlock {
        Add-GitHubIssueComment -Issue 12 -Body ' '
    } -MessageLike '-Body is blank, and GitHub refuses an empty comment. Give the text.' `
        -Message 'A comment of white space alone is refused'
    Assert-Throws -ScriptBlock {
        Add-GitHubIssueComment -Issue 12 -Body ''
    } -MessageLike '-Body is blank, and GitHub refuses an empty comment. Give the text.' `
        -Message 'and an empty one gets the same sentence'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - issues from the pipeline, same body
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Add-GitHubIssueComment -Body 'Ping'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)
    $files = @($calls.ForEach({ Get-IssueTextFile -Call $_ }))

    # Assert
    Assert-Equal -Expected @('1', '2') -Actual @($calls.ForEach({ $_.Arguments[2] })) `
        -Message 'Each piped issue gets its own comment call'
    Assert-Equal -Expected @('Ping', 'Ping') -Actual @($files.Text) -Message 'each with the comment'
    Assert-That -Condition ($files[0].Path -ne $files[1].Path) -Message 'in a file of its own'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refuses the comment
$fake = New-FakeGitHubCli `
    -ErrorOutput @('GraphQL: Could not resolve to an issue with the number of 12. (repository.issue)') `
    -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubIssueComment -Issue 12 -Body 'Hi'
    } -MessageLike '*Commenting on issue 12 failed*Could not resolve to an issue*' `
        -Message 'A failure throws with the message from gh'

    # Act
    $path = (Get-IssueTextFile -Call @(Get-FakeGitHubCall -Fixture $fake)[0]).Path

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $path) -Message 'and the file is gone all the same'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with each kind of comment
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubIssueComment -Issue 12 -Body 'Secret text' -Repository 'o/r' -WhatIf
        Add-GitHubIssueComment -Issue 12 -Body 'Secret text' -EditLast -Repository 'o/r' -WhatIf
        Add-GitHubIssueComment -Issue 12 -Body 'Secret text' -EditLast -CreateIfNone -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Add comment" on target "o/r issue #12".'
        'What if: Performing the operation "Edit last comment" on target "o/r issue #12".'
        'What if: Performing the operation "Edit last comment, or add one" on target "o/r issue #12".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the issue and the change, never the comment'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and comments nowhere'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank comment, and with -CreateIfNone alone
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubIssueComment -Issue 12 -Body ' ' -WhatIf
    } -MessageLike '-Body is blank, and GitHub refuses an empty comment. Give the text.' `
        -Message '-WhatIf still refuses a blank comment'
    Assert-Throws -ScriptBlock {
        Add-GitHubIssueComment -Issue 12 -Body 'Hi' -CreateIfNone -WhatIf
    } -MessageLike '-CreateIfNone works only with -EditLast*' -Message 'and -CreateIfNone without -EditLast'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two issues piped under -WhatIf, on an Enterprise host
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        $issues = @('1', 'https://ghe.example.com/o/r/issues/2')
        $issues | Add-GitHubIssueComment -Body 'Hi' -Repository 'ghe.example.com/o/r' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Add comment" on target "ghe.example.com/o/r issue #1".'
        'What if: Performing the operation "Add comment" on target "ghe.example.com/o/r issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped issue'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and comments on neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
