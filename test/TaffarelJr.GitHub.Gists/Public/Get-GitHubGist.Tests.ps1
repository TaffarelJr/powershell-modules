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
# Arrange - one gist by id
$fake = New-FakeGitHubCli -Output @('{"id":"abc123","description":"notes","files":{"a.txt":{"content":"hi"}}}')
try {
    # Act
    $gist = Get-GitHubGist -Id 'abc123'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists/abc123') -Actual $call.Arguments -Message 'The id is embedded directly in the endpoint path'
    Assert-Equal -Expected 'notes' -Actual $gist.Description -Message 'The gist comes back as one object with PascalCase fields'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the id given as a full URL, as gist view accepts
$fake = New-FakeGitHubCli -Output @('{"id":"abc123"}')
try {
    # Act
    Get-GitHubGist -Id 'https://gist.github.com/me/abc123' | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists/abc123') -Actual $call.Arguments -Message 'A gist URL is reduced to its bare id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing gists
$fake = New-FakeGitHubCli -Output @('[{"id":"a"},{"id":"b"}]')
try {
    # Act
    $gists = Get-GitHubGist -List
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists') -Actual $call.Arguments -Message 'Listing calls the gists collection endpoint'
    Assert-Equal -Expected 2 -Actual $gists.Count -Message 'Every listed gist is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every gist, paginated, one result
$fake = New-FakeGitHubCli -Output @('[{"id":"a"}]')
try {
    # Act
    $gists = Get-GitHubGist -List -All
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists', '--paginate', '--slurp') -Actual $call.Arguments -Message '-All asks for every page'
    Assert-That -Condition ($gists -is [array]) -Message 'A single listed gist is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
