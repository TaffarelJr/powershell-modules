#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'bucket,completedAt,description,event,link,name,startedAt,state,workflow'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every check passed
$fake = New-FakeGitHubCli -Output @('[{"name":"build","state":"SUCCESS","bucket":"pass"}]')
try {
    # Act
    $checks = Get-GitHubPullRequestCheck -PullRequest 12 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'checks', '12', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The checks are asked for as JSON with a fixed field set'
    Assert-That -Condition ($checks -is [array]) -Message 'A single check is still returned as an array'
    Assert-Equal -Expected 'pass' -Actual $checks[0].Bucket -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed check, which gh reports through a non-zero exit
$fake = New-FakeGitHubCli -Output @('[{"name":"test","state":"FAILURE","bucket":"fail"}]') -ExitCode 1
try {
    # Act
    $checks = Get-GitHubPullRequestCheck

    # Assert
    Assert-Equal -Expected 'fail' -Actual $checks[0].Bucket -Message 'A failing check is returned for the caller to judge, not thrown'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - checks still pending, gh''s exit code 8
$fake = New-FakeGitHubCli -Output @('[{"name":"deploy","state":"PENDING","bucket":"pending"}]') -ExitCode 8
try {
    # Act
    $checks = Get-GitHubPullRequestCheck -Watch -FailFast -Interval 5 -Required
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'checks', '--json', $fields, '--required', '--watch', '--fail-fast', '--interval', '5') -Actual $call.Arguments -Message 'Each option becomes its gh flag'
    Assert-Equal -Expected 'pending' -Actual $checks[0].Bucket -Message 'A pending check is returned for the caller to judge, not thrown'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failure that produced no checks at all
$fake = New-FakeGitHubCli -Output @('no pull requests found for branch "x"') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Get-GitHubPullRequestCheck -PullRequest 'x' } -Message 'A failure with no JSON to show for it throws'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
