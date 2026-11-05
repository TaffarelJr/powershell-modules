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
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failure in each kind of block, under each -ErrorAction a caller can give. A plain throw would be
# skipped under SilentlyContinue and Ignore, and the call would go on to change something.
$preferences = 'SilentlyContinue', 'Ignore', 'Stop'
$failing = @{ ExitCode = 1; ErrorOutput = 'gh: boom' }
$failures = @(
    @{
        Block = { Set-GitHubGist -Id 'abc123' -FileName 'a.txt' -ErrorAction $preference }
        Id    = 'RuntimeException,Set-GitHubGist'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a begin block'
    }
    @{
        Block = { Remove-GitHubGist -Id 'not a gist!' -ErrorAction $preference }
        Id    = 'RuntimeException,Remove-GitHubGist'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a process block'
    }
    @{
        Block = { Remove-GitHubGist -Id 'abc123' -ErrorAction $preference }
        Id    = '*,Remove-GitHubGist'
        Fake  = $failing
        Calls = 1
        Name  = 'a gh failure in a process block'
    }
    @{
        Block = { New-GitHubGist -Content ' ' -FileName 'a.txt' -ErrorAction $preference }
        Id    = 'RuntimeException,New-GitHubGist'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a function with no named block'
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
# Arrange - a gh failure in a function with no named block, which the module's API wrapper reports with a typed
# exception, so there is no text to be the target
foreach ($preference in $preferences) {
    $fake = New-FakeGitHubCli @failing
    try {
        # Act
        $run = Get-WhatIfOutput -CaptureError -ScriptBlock {
            New-GitHubGist -Content 'x' -FileName 'a.txt' -ErrorAction $preference
        }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)
        $record = $run.Error

        # Assert
        $because = "A gh failure in a function with no named block, under -ErrorAction $preference"
        Assert-Equal -Expected 1 -Actual $calls.Count -Message "$because, is the one call made"
        Assert-Equal -Expected 0 -Actual $run.Output.Count -Message "$because, returns nothing"
        Assert-Equal -Expected 'InvalidOperationException,New-GitHubGist' -Actual $record.FullyQualifiedErrorId `
            -Message "$because, names the exception type and the command"
        Assert-Equal -Expected 'InvalidOperation' -Actual "$($record.CategoryInfo.Category)" `
            -Message "$because, gives a category a caller can act on"
        Assert-Equal -Expected $null -Actual $record.TargetObject -Message "$because, has no target"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the second of three piped gists is no gist
foreach ($preference in 'SilentlyContinue', 'Stop') {
    $fake = New-FakeGitHubCli
    try {
        # Act
        $run = Get-WhatIfOutput -CaptureError -ScriptBlock {
            @('abc123', 'not a gist!', 'def456') | Remove-GitHubGist -ErrorAction $preference
        }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        $because = "Under -ErrorAction $preference, the pipeline stops at the failing gist"
        Assert-Equal -Expected 1 -Actual $calls.Count -Message "${because}: the one after it is not deleted"
        Assert-Equal -Expected @('gist', 'delete', 'abc123', '--yes') -Actual $calls[0].Arguments `
            -Message "$because, and the one before it was deleted"
        Assert-That -Condition ($run.Error.FullyQualifiedErrorId -clike 'RuntimeException,Remove-GitHubGist') `
            -Message "$because, with a terminating error"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing that a later command stops reading after its first item
$listing = '[[{"id":"a1","html_url":"https://gist.github.com/me/a1"},' +
'{"id":"b2","html_url":"https://gist.github.com/me/b2"}]]'
$fake = New-FakeGitHubCli -Output $listing
try {
    # Act
    $first = @(Get-GitHubGist -List | Select-Object -First 1)

    # Assert
    Assert-Equal -Expected 1 -Actual $first.Count -Message 'A downstream Select-Object -First 1 gets one gist'
    Assert-Equal -Expected 'a1' -Actual $first[0].Id `
        -Message 'the first, with no error raised for stopping the listing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
