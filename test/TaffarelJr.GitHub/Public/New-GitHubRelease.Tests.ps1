#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a draft with inline notes and a target commit
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/releases/tag/v1.0.0')
try {
    # Act
    $url = New-GitHubRelease -Tag 'v1.0.0' -Title 'v1.0.0' -Notes "## Changes`n- one" -Draft -Target 'abc123' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'create', 'v1.0.0', '--title', 'v1.0.0', '--notes-file', '-', '--draft', '--target', 'abc123', '--repo', 'o/r') -Actual $call.Arguments -Message 'Notes are read from standard input; the rest become their gh flags'
    Assert-Equal -Expected "## Changes`n- one" -Actual $call.StdIn -Message 'The notes themselves are what gets piped'
    Assert-Equal -Expected 'https://github.com/o/r/releases/tag/v1.0.0' -Actual $url -Message 'The new release''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other option, with assets, notes from a file
$fake = New-FakeGitHubCli -Output @('Uploading a.zip...', 'https://github.com/o/r/releases/tag/v2')
try {
    # Act
    $url = New-GitHubRelease -Tag 'v2' -Asset @('a.zip', 'b.zip#Label') -NotesFile 'notes.md' -GenerateNotes -NotesStartTag 'v1' -NotesFromTag -Prerelease -Latest:$false -VerifyTag -DiscussionCategory 'General' -FailOnNoCommits
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'create', 'v2', 'a.zip', 'b.zip#Label', '--notes-file', 'notes.md', '--generate-notes', '--notes-start-tag', 'v1', '--notes-from-tag', '--prerelease', '--latest=false', '--verify-tag', '--discussion-category', 'General', '--fail-on-no-commits') -Actual $call.Arguments -Message 'Assets follow the tag and each option becomes its gh flag, -Latest as a three-state toggle'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Notes'
    Assert-Equal -Expected 'https://github.com/o/r/releases/tag/v2' -Actual $url -Message 'The URL is picked out from among upload progress lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - explicitly latest
$fake = New-FakeGitHubCli -Output @('https://x')
try {
    # Act
    New-GitHubRelease -Tag 'v3' -Latest | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'create', 'v3', '--latest=true') -Actual $call.Arguments -Message '-Latest alone marks the release latest'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
