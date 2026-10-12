#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a call that succeeds
$fake = New-FakeGitHubCli -Output @('{"id":"abc123"}')
try {
    # Act
    $gist = & $module { Invoke-GitHubGistApi -Activity 'Reading gist abc123' -Request @{ Endpoint = 'gists/abc123' } }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists/abc123') -Actual $call.Arguments `
        -Message 'The request is made as Invoke-GitHubApi makes it'
    Assert-Equal -Expected 'abc123' -Actual $gist.id -Message 'and its answer is returned as it parses it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Not Found (HTTP 404)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Invoke-GitHubGistApi -Activity 'Reading gist abc123' -Request @{ Endpoint = 'gists/abc123' } }
    } -MessageLike 'Reading gist abc123 failed: gh api gists/abc123 (exit 1)*Not Found (HTTP 404)' `
        -Message 'A failure is told as what the caller was doing, not as the endpoint called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an answer that is not JSON
$fake = New-FakeGitHubCli -Output @('<html>')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Invoke-GitHubGistApi -Activity 'Reading gist abc123' -Request @{ Endpoint = 'gists/abc123' } }
    } -MessageLike 'Reading gist abc123 failed: The response from gists/abc123 is not JSON*' `
        -Message 'Any other failure keeps its own message after the caller''s words'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
