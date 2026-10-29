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
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failure in each kind of block, under each -ErrorAction a caller can give. A plain throw would be
# skipped under SilentlyContinue and Ignore, and the call would go on to change something.
$preferences = 'SilentlyContinue', 'Ignore', 'Stop'
$failing = @{ ExitCode = 1; ErrorOutput = 'gh: boom' }
$failures = @(
    @{
        Block = {
            Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.zip' -Archive zip -Repository 'o/r' -ErrorAction $preference
        }
        Id    = 'RuntimeException,Save-GitHubReleaseAsset'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a begin block'
    }
    @{
        Block = { Save-GitHubReleaseAsset -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,Save-GitHubReleaseAsset'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a process block'
    }
    @{
        Block = { Remove-GitHubReleaseAsset -Tag 'v1' -Name ' ' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,Remove-GitHubReleaseAsset'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a process block of another function'
    }
    @{
        Block = { Remove-GitHubRelease -Tag 'v1' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,*Remove-GitHubRelease'
        Fake  = $failing
        Calls = 1
        Name  = 'a gh failure in a process block'
    }
    @{
        Block = {
            'a.zip', [PSCustomObject]@{ Name = 'x' } |
                Add-GitHubReleaseAsset -Tag 'v1' -Repository 'o/r' -ErrorAction $preference
        }
        Id    = 'RuntimeException,Add-GitHubReleaseAsset'
        Fake  = @{}
        Calls = 0
        Name  = 'a failing record, after one that was gathered, in a process block that gathers'
    }
    @{
        Block = { Add-GitHubReleaseAsset -Tag 'v1' -Path 'a.zip' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,*Add-GitHubReleaseAsset'
        Fake  = $failing
        Calls = 1
        Name  = 'a gh failure in an end block'
    }
    @{
        Block = { New-GitHubRelease -Tag 'v1' -Notes 'a' -NotesFile 'b.md' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,New-GitHubRelease'
        Fake  = @{}
        Calls = 0
        Name  = 'a failure in a function with no named block'
    }
    @{
        Block = { New-GitHubRelease -Tag 'v1' -Repository 'o/r' -ErrorAction $preference }
        Id    = 'RuntimeException,*New-GitHubRelease'
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
# Arrange - the second of three piped tags is no tag
foreach ($preference in 'SilentlyContinue', 'Stop') {
    $fake = New-FakeGitHubCli
    try {
        # Act
        $run = Get-WhatIfOutput -CaptureError -ScriptBlock {
            @('v1', ' ', 'v3') | Remove-GitHubRelease -Repository 'o/r' -ErrorAction $preference
        }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        $because = "Under -ErrorAction $preference, the pipeline stops at the failing tag"
        Assert-Equal -Expected 1 -Actual $calls.Count -Message "${because}: the one after it is not deleted"
        Assert-Equal -Expected @('release', 'delete', '--yes', '--repo', 'o/r', '--', 'v1') `
            -Actual $calls[0].Arguments -Message "$because, and the one before it was deleted"
        Assert-That -Condition ($run.Error.FullyQualifiedErrorId -clike 'RuntimeException,Remove-GitHubRelease') `
            -Message "$because, with a terminating error"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing that a later command stops reading after its first item
$listing = '[{"tagName":"v1"},{"tagName":"v2"}]'
$fake = New-FakeGitHubCli -Output $listing
try {
    # Act
    $first = @(Get-GitHubRelease -List -Repository 'o/r' | Select-Object -First 1)

    # Assert
    Assert-Equal -Expected 1 -Actual $first.Count -Message 'A downstream Select-Object -First 1 gets one release'
    Assert-Equal -Expected 'v1' -Actual $first[0].TagName `
        -Message 'the first, with no error raised for stopping the listing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
