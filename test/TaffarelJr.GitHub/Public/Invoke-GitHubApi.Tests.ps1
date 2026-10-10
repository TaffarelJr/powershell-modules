#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a plain GET answered with a REST object
$fake = New-FakeGitHubCli -Output @('{"default_branch":"main","id":1}')
try {
    # Act
    $response = Invoke-GitHubApi -Endpoint 'repos/o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r') -Actual $call.Arguments -Message 'A bare endpoint is the only argument gh gets'
    Assert-Equal -Expected 'main' -Actual $response.default_branch -Message "The response keeps GitHub's own snake_case field names"
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a write with typed and raw fields
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    Invoke-GitHubApi -Endpoint 'repos/o/r/git/refs/tags/v1' -Method patch -Field @{ sha = 'abc'; force = $true } -RawField @{ ref = 'refs/tags/v1' } | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/git/refs/tags/v1', '--method', 'PATCH', '--field', 'force=true', '--field', 'sha=abc', '--raw-field', 'ref=refs/tags/v1') -Actual $call.Arguments -Message '-Method is upper-cased and -Field/-RawField become sorted -F/-f pairs'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a header, a preview, and another host
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    Invoke-GitHubApi -Endpoint 'user' -Header @{ Accept = 'application/vnd.github+json' } -Preview @('nebula') -Hostname 'ghe.example' | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'user', '--header', 'Accept: application/vnd.github+json', '--preview', 'nebula', '--hostname', 'ghe.example') -Actual $call.Arguments -Message 'Headers, previews, and the hostname each become their gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pre-built body
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    Invoke-GitHubApi -Endpoint 'repos/o/r/rulesets' -Body '{"name":"x"}' | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets', '--input', '-') -Actual $call.Arguments -Message '-Body tells gh to read its request body from standard input'
    Assert-Equal -Expected '{"name":"x"}' -Actual $call.StdIn -Message 'The body itself is what gets piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a jq expression
$fake = New-FakeGitHubCli -Output @('octocat')
try {
    # Act
    $lines = Invoke-GitHubApi -Endpoint 'user' -Jq '.login'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'user', '--jq', '.login') -Actual $call.Arguments -Message '-Jq is passed through'
    Assert-That -Condition ($lines -is [array]) -Message 'A jq result comes back as text lines, as an array'
    Assert-Equal -Expected 'octocat' -Actual $lines[0] -Message 'The jq result is not parsed as JSON'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a silent write
$fake = New-FakeGitHubCli
try {
    # Act
    $nothing = Invoke-GitHubApi -Endpoint 'repos/o/r/private-vulnerability-reporting' -Method PUT -Silent
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/private-vulnerability-reporting', '--method', 'PUT', '--silent') -Actual $call.Arguments -Message '-Silent is passed through'
    Assert-That -Condition ($null -eq $nothing) -Message '-Silent returns nothing at all'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a paginated list endpoint, answered as slurped pages
$fake = New-FakeGitHubCli -Output @('[[{"n":1},{"n":2}],[{"n":3}]]')
try {
    # Act
    $items = Invoke-GitHubApi -Endpoint 'repos/o/r/releases' -Paginate
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/releases', '--paginate', '--slurp') -Actual $call.Arguments -Message '-Paginate asks gh for every page, slurped into one document'
    Assert-Equal -Expected 3 -Actual $items.Count -Message 'Pages of a list endpoint are flattened into one array of items'
    Assert-Equal -Expected 3 -Actual $items[2].n -Message 'Items keep their order across pages'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - paginated GraphQL, where each page is an object
$fake = New-FakeGitHubCli -Output @('[{"data":{"a":1}},{"data":{"a":2}}]')
try {
    # Act
    $pages = Invoke-GitHubApi -Endpoint 'graphql' -Paginate -RawField @{ query = 'q' }

    # Assert
    Assert-Equal -Expected 2 -Actual $pages.Count -Message 'Object pages are returned one per page, not flattened'
    Assert-Equal -Expected 2 -Actual $pages[1].data.a -Message 'Each page object is intact'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a one-element array response, and an empty response
$fake = New-FakeGitHubCli -Output @('[{"id":9}]')
try {
    # Act
    $single = Invoke-GitHubApi -Endpoint 'repos/o/r/tags'

    # Assert
    Assert-That -Condition ($single -is [array]) -Message 'A one-element array response stays an array'
    Assert-Equal -Expected 9 -Actual $single[0].id -Message 'The one element is parsed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-That -Condition ($null -eq (Invoke-GitHubApi -Endpoint 'repos/o/r/topics' -Method PUT)) -Message 'An empty response body parses to $null'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a response that is not JSON
$fake = New-FakeGitHubCli -Output @('# README', 'text')
try {
    # Act
    $raw = Invoke-GitHubApi -Endpoint 'repos/o/r/readme' -Raw

    # Assert
    Assert-Equal -Expected @('# README', 'text') -Actual $raw -Message '-Raw returns the lines unparsed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails
$fake = New-FakeGitHubCli -Output @('{"message":"Not Found"}') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Invoke-GitHubApi -Endpoint 'repos/o/missing' } -Message 'A failed request throws'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
