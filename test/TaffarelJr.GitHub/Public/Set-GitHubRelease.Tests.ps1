#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - publishing a draft
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRelease -Tag 'v1.0.0' -Draft:$false -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'edit', 'v1.0.0', '--draft=false', '--repo', 'o/r') -Actual $call.Arguments -Message '-Draft:$false publishes the draft'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Notes'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRelease -Tag 'v1' -Title 'One' -Notes 'Body' -NotesFile 'n.md' -NewTag 'v1.0.0' -Target 'main' -Draft -Prerelease -Latest:$false -VerifyTag -DiscussionCategory 'General'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'edit', 'v1', '--title', 'One', '--notes-file', '-', '--notes-file', 'n.md', '--tag', 'v1.0.0', '--target', 'main', '--draft=true', '--prerelease=true', '--latest=false', '--verify-tag', '--discussion-category', 'General') -Actual $call.Arguments -Message 'Each option becomes its gh flag, the toggles as explicit booleans'
    Assert-Equal -Expected 'Body' -Actual $call.StdIn -Message 'The notes are what gets piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
