#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$cases = @(
    @{
        Name = 'Add-GitHubPullRequestComment'
        Call = { Add-GitHubPullRequestComment -PullRequest 42 -Body 'b' -Repository 'o/r' }
    }
    @{ Name = 'Close-GitHubPullRequest'; Call = { Close-GitHubPullRequest -PullRequest 42 -Repository 'o/r' } }
    @{ Name = 'Lock-GitHubPullRequest'; Call = { Lock-GitHubPullRequest -PullRequest 42 -Repository 'o/r' } }
    @{
        Name = 'Merge-GitHubPullRequest'
        Call = { Merge-GitHubPullRequest -PullRequest 42 -Strategy squash -Repository 'o/r' }
    }
    @{
        Name = 'New-GitHubPullRequest'
        Call = { New-GitHubPullRequest -Title 't' -Body 'b' -Base 'main' -Head 'topic' -Repository 'o/r' }
    }
    @{ Name = 'Open-GitHubPullRequest'; Call = { Open-GitHubPullRequest -PullRequest 42 -Repository 'o/r' } }
    @{
        Name = 'Set-GitHubPullRequest'
        Call = { Set-GitHubPullRequest -PullRequest 42 -Title 't' -Repository 'o/r' }
    }
    @{
        Name = 'Submit-GitHubPullRequestReview'
        Call = { Submit-GitHubPullRequestReview -PullRequest 42 -Decision Approve -Repository 'o/r' }
    }
    @{ Name = 'Switch-GitHubPullRequest'; Call = { Switch-GitHubPullRequest -PullRequest 42 -Repository 'o/r' } }
    @{ Name = 'Unlock-GitHubPullRequest'; Call = { Unlock-GitHubPullRequest -PullRequest 42 -Repository 'o/r' } }
    @{
        Name = 'Update-GitHubPullRequestBranch'
        Call = { Update-GitHubPullRequestBranch -PullRequest 42 -Repository 'o/r' }
    }
)

foreach ($case in $cases) {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function run with -WhatIf, calling the command that changes things
    $fake = New-FakeGitHubCli
    try {
        # Act
        $whatIf = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $case.Call -WhatIf }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        Assert-Equal -Expected 1 -Actual $whatIf.Messages.Count `
            -Message "$($case.Name) reaches its guard under its caller's -WhatIf, and says what it would do"
        Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and changes nothing: gh is never called'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
