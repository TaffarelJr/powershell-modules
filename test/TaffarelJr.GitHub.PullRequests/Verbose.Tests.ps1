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

$line = 'Reading pull request 42: gh pr view 42 --json number,url --repo o/r'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a reader that runs gh, called with its own -Verbose
$fake = New-FakeGitHubCli -Output @('{"number":42}')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Get-GitHubPullRequest -PullRequest 42 -Property number -Repository 'o/r' -Verbose
        })

    # Assert
    Assert-Equal -Expected @($line) -Actual $lines -Message 'A call given -Verbose prints the command line it runs'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same reader, called from a function whose $VerbosePreference is Continue
$fake = New-FakeGitHubCli -Output @('{"number":42}')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller { Get-GitHubPullRequest -PullRequest 42 -Property number -Repository 'o/r' }
        })

    # Assert
    Assert-Equal -Expected @($line) -Actual $lines `
        -Message 'A call from a function that set $VerbosePreference prints the command line too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same caller, and a call that turns -Verbose off for itself
$fake = New-FakeGitHubCli -Output @('{"number":42}')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller {
                Get-GitHubPullRequest -PullRequest 42 -Property number -Repository 'o/r' -Verbose:$false
            }
        })

    # Assert
    Assert-Equal -Expected @() -Actual $lines `
        -Message 'A call given -Verbose:$false prints nothing, whatever its caller prefers'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
