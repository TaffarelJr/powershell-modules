#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - local files
$fake = New-FakeGitHubCli -Output @('https://gist.github.com/me/abc123')
try {
    # Act
    $url = New-GitHubGist -Path @('a.txt', 'b.txt') -Description 'notes' -Public
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'create', 'a.txt', 'b.txt', '--desc', 'notes', '--public') -Actual $call.Arguments -Message 'The files are positional and the rest become their gh flags'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped for a file-based gist'
    Assert-Equal -Expected 'https://gist.github.com/me/abc123' -Actual $url -Message "The new gist's URL is returned"
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - content piped in, named
$fake = New-FakeGitHubCli -Output @('https://gist.github.com/me/def456')
try {
    # Act
    $url = New-GitHubGist -Content "line 1`nline 2" -FileName 'notes.md'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'create', '--filename', 'notes.md') -Actual $call.Arguments -Message 'No files are positional when creating from content'
    Assert-Equal -Expected "line 1`nline 2" -Actual $call.StdIn -Message 'The content itself is what gets piped'
    Assert-Equal -Expected 'https://gist.github.com/me/def456' -Actual $url -Message 'The URL is returned for a content-based gist too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
