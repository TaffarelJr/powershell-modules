#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the tables hand to Get-WhatIfOutput, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failure in each kind of block, under each -ErrorAction a caller can give. A plain throw would be
# skipped under SilentlyContinue and Ignore, and the call would go on to change something.
$preferences = 'SilentlyContinue', 'Ignore', 'Stop'
$failing = @{ ExitCode = 1; ErrorOutput = 'gh: boom' }
$failures = @(
    @{
        Block = { Close-GitHubIssue -Issue 12 -Comment ' ' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,Close-GitHubIssue'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a begin block'
    }
    @{
        Block = { Close-GitHubIssue -Issue 'not-an-issue' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,*Close-GitHubIssue'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a process block'
    }
    @{
        Block = { Close-GitHubIssue -Issue 12 -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,*Close-GitHubIssue'
        Fake  = $failing
        Calls = 1
        Name  = 'a gh failure in a process block'
    }
    @{
        Block = { New-GitHubIssue -Title ' ' -Body 'x' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,New-GitHubIssue'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a function with no named block'
    }
    @{
        Block = { Get-GitHubIssueStatus -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,*Get-GitHubIssueStatus'
        Fake  = $failing
        Calls = 1
        Name  = 'a gh failure in a function with no named block'
    }
)
foreach ($failure in $failures) {
    foreach ($preference in $preferences) {
        $fakeArguments = $failure.Fake
        $fake = New-FakeGitHubCli @fakeArguments
        try {
            # Act
            $run = Get-WhatIfOutput -CaptureError -ScriptBlock $failure.Block
            $calls = @(Get-FakeGitHubCall -Fixture $fake)
            $record = $run.Error

            # Assert
            $because = "$($failure.Name), under -ErrorAction $preference"
            Assert-Equal -Expected $failure.Calls -Actual $calls.Count `
                -Message "$because, goes on to no change"
            Assert-Equal -Expected 0 -Actual $run.Output.Count -Message "$because, returns nothing"
            Assert-That -Condition ($null -ne $record) -Message "$because, raises a terminating error"
            Assert-That -Condition ($record.FullyQualifiedErrorId -clike $failure.Id) `
                -Message "$because, names the kind of failure and the command"
            Assert-Equal -Expected 'InvalidOperation' -Actual "$($record.CategoryInfo.Category)" `
                -Message "$because, gives a category a caller can act on"
            Assert-Equal -Expected $record.Exception.Message -Actual $record.TargetObject `
                -Message "$because, keeps the failure's message as its target"
        }
        finally {
            Remove-FakeGitHubCli -Fixture $fake
        }
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the second of three piped issues is no issue
foreach ($preference in 'SilentlyContinue', 'Stop') {
    $fake = New-FakeGitHubCli
    try {
        # Act
        $run = Get-WhatIfOutput -CaptureError -ScriptBlock {
            @('1', 'bad', '3') | Close-GitHubIssue -Repository 'o/r' -ErrorAction $preference
        }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        $because = "Under -ErrorAction $preference, the pipeline stops at the failing issue"
        Assert-Equal -Expected 1 -Actual $calls.Count -Message "${because}: the one after it is not closed"
        Assert-Equal -Expected @('issue', 'close', '1', '--repo', 'o/r') -Actual $calls[0].Arguments `
            -Message "$because, and the one before it was closed"
        Assert-That -Condition ($run.Error.FullyQualifiedErrorId -clike 'RuntimeException,*Close-GitHubIssue') `
            -Message "$because, with a terminating error"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing that a later command stops reading after its first item
$listing = '[{"number":1,"url":"https://github.com/o/r/issues/1"},{"number":2,"url":"https://github.com/o/r/issues/2"}]'
$fake = New-FakeGitHubCli -Output $listing
try {
    # Act
    $first = @(Get-GitHubIssue -List -Repository 'o/r' | Select-Object -First 1)

    # Assert
    Assert-Equal -Expected 1 -Actual $first.Count -Message 'A downstream Select-Object -First 1 gets one issue'
    Assert-Equal -Expected 1 -Actual $first[0].Number `
        -Message 'the first, with no error raised for stopping the listing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
