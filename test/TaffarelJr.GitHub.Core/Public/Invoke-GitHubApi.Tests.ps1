#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a plain GET answered with a REST object
$fake = New-FakeGitHubCli -Output @('{"default_branch":"main","id":1}')
try {
    # Act
    $response = Invoke-GitHubApi -Endpoint 'repos/o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r') -Actual $call.Arguments `
        -Message 'A bare endpoint is the only argument gh gets'
    Assert-Equal -Expected 'main' -Actual $response.default_branch `
        -Message "The response keeps GitHub's own snake_case field names"
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
    Invoke-GitHubApi -Endpoint 'repos/o/r/git/refs/tags/v1' -Method patch -Field @{
        sha = 'abc'
        force = $true
    } -RawField @{ ref = 'refs/tags/v1' } | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'api', 'repos/o/r/git/refs/tags/v1', '--method', 'PATCH', '--field', 'force=true', '--field', 'sha=abc',
            '--raw-field', 'ref=refs/tags/v1'
        ) `
        -Actual $call.Arguments `
        -Message '-Method is upper-cased and -Field/-RawField become sorted -F/-f pairs'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'api', 'user', '--header', 'Accept: application/vnd.github+json', '--preview', 'nebula', '--hostname',
            'ghe.example'
        ) `
        -Actual $call.Arguments `
        -Message 'Headers, previews, and the hostname each become their gh flag'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets', '--input', '-') -Actual $call.Arguments `
        -Message '-Body tells gh to read its request body from standard input'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'user', '--jq', '.login') -Actual $call.Arguments -Message '-Jq is passed through'
    Assert-Equal -Expected 'octocat' -Actual $lines -Message 'A jq result comes back as text lines, not parsed as JSON'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/private-vulnerability-reporting', '--method', 'PUT', '--silent') `
        -Actual $call.Arguments `
        -Message '-Silent is passed through'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/releases', '--paginate', '--slurp') -Actual $call.Arguments `
        -Message '-Paginate asks gh for every page, slurped into one document'
    Assert-Equal -Expected 3 -Actual $items.Count `
        -Message 'Pages of a list endpoint are flattened into one sequence of items'
    Assert-Equal -Expected 3 -Actual $items[2].n -Message 'Items keep their order across pages'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a paginated list endpoint with a single item on its only page, and one with none
$fake = New-FakeGitHubCli -Output @('[[{"n":1}]]')
try {
    # Act
    $onlyItem = Invoke-GitHubApi -Endpoint 'repos/o/r/releases' -Paginate

    # Assert
    Assert-That -Condition ($onlyItem -isnot [array]) `
        -Message 'A single item on a single page comes out as that one item'
    Assert-Equal -Expected 1 -Actual $onlyItem.n -Message 'and it is intact'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act / Assert
    Assert-Equal -Expected 0 -Actual @(Invoke-GitHubApi -Endpoint 'repos/o/r/releases' -Paginate).Count `
        -Message 'One empty page, as gh slurps an empty list, writes nothing'
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
# Arrange - a one-element array response, a longer one, an empty one, and an empty body
$fake = New-FakeGitHubCli -Output @('[{"id":9}]')
try {
    # Act
    $single = Invoke-GitHubApi -Endpoint 'repos/o/r/tags'

    # Assert
    Assert-That -Condition ($single -isnot [array]) `
        -Message 'A one-element array response comes out as that one element'
    Assert-Equal -Expected 9 -Actual $single.id -Message 'The one element is parsed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli -Output @('[{"id":1},{"id":2}]')
try {
    # Act
    $piped = Invoke-GitHubApi -Endpoint 'repos/o/r/tags' | Measure-Object

    # Assert
    Assert-Equal -Expected 2 -Actual $piped.Count `
        -Message 'Each element of an array response is its own pipeline item, so the call pipes straight on'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act / Assert
    Assert-Equal -Expected 0 -Actual @(Invoke-GitHubApi -Endpoint 'repos/o/r/tags').Count `
        -Message 'An empty array response writes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli -Output @('{"id":1,"labels":[{"name":"bug"}]}')
try {
    # Act
    $object = Invoke-GitHubApi -Endpoint 'repos/o/r/issues/1'

    # Assert
    Assert-That -Condition ($object.labels -is [array] -and $object.labels.Count -eq 1) `
        -Message 'A one-element array inside an object response stays an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Equal -Expected 0 -Actual @(Invoke-GitHubApi -Endpoint 'repos/o/r/topics' -Method PUT).Count `
        -Message 'An empty response body writes nothing'
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
    Assert-Throws -ScriptBlock {
        Invoke-GitHubApi -Endpoint 'repos/o/missing'
    } -MessageLike '*Calling repos/o/missing failed*(exit 1)*Not Found*' `
        -Message 'A failed request throws, naming what was called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a good response with a notice on stderr beside it, as GH_DEBUG or a
# deprecation warning would write
$fake = New-FakeGitHubCli -Output @('{"id":1}') -ErrorOutput @('warning: a notice from gh')
try {
    # Act
    $noisy = Invoke-GitHubApi -Endpoint 'repos/o/r'

    # Assert
    Assert-Equal -Expected 1 -Actual $noisy.id -Message 'A notice on stderr does not break parsing the response'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a response that is plainly not JSON, asked for without -Raw
$fake = New-FakeGitHubCli -Output @('diff --git a/x b/x', '+added')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubApi -Endpoint 'repos/o/r/pulls/1'
    } -MessageLike "*The response from repos/o/r/pulls/1 is not JSON - give -Raw to read it as text. gh's output is not valid JSON, starting 'diff --git*': *." `
        -Message 'Says so, with the way out and a look at what came back'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failure the way gh reports one
$fake = New-FakeGitHubCli -Output @('{"message":"Not Found"}') -ErrorOutput @('gh: Not Found (HTTP 404)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubApi -Endpoint 'repos/o/missing'
    } -MessageLike '*Calling repos/o/missing failed*Not Found (HTTP 404)*' `
        -Message 'The failure names what was called and carries gh''s reason'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a request with a nested typed field and an ordered raw field
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    Invoke-GitHubApi -Endpoint 'repos/o/r/branches/main/protection' -Method PUT `
        -Field @{ required_status_checks = @{ strict = $true; contexts = @('ci') } } -RawField ([ordered]@{ note = 'x' }) | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/branches/main/protection', '--method', 'PUT',
        '--field', 'required_status_checks[contexts][]=ci', '--field', 'required_status_checks[strict]=true', '--raw-field', 'note=x') `
        -Actual $call.Arguments `
            -Message 'A nested field is sent as bracketed keys, and an ordered dictionary is accepted'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an endpoint gh would read as an option
Assert-Throws -ScriptBlock {
    Invoke-GitHubApi -Endpoint '--hostname'
} -MessageLike "*'--hostname' starts with '-', which gh would read as an option." `
    -Message 'An endpoint starting with a dash is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Invoke-GitHubApi -Endpoint ' ' } `
        -MessageLike "Cannot validate argument on parameter 'Endpoint'. -Endpoint is blank: *" `
        -Message 'A blank endpoint is refused'
    Assert-Throws -ScriptBlock { Invoke-GitHubApi -Endpoint 'repos/o/r/topics' -Method PUT -Body $null } `
        -MessageLike '-Body is $null: give the request body as text, or leave -Body out to send none.' `
        -Message 'and so is a -Body given as $null, which would send an empty body'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is run'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Invoke-GitHubApi -Endpoint 'repos/o/r/topics' -Method PUT -Body @{ names = @() } } `
        -MessageLike '-Body is a Hashtable: give the request body as text, such as ConvertTo-Json writes it.' `
        -Message 'A -Body that is not text is refused rather than sent as its type name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - host names gh could only fail to find, and an empty one
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($hostname in 'ghe.example:8443', '') {
        Assert-Throws -ScriptBlock {
            Invoke-GitHubApi -Endpoint 'user' -Hostname $hostname
        } -MessageLike "*'$hostname' is not a host name: give it bare*or leave -Hostname out for the default host." `
            -Message "-Hostname '$hostname' is refused as Assert-GitHubHostname refuses it"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is run'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - paginated reads that are not parsed here
$fake = New-FakeGitHubCli -Output @('v1', 'v2')
try {
    # Act
    $names = Invoke-GitHubApi -Endpoint 'repos/o/r/releases' -Paginate -Jq '.[].tag_name'
    $text = Invoke-GitHubApi -Endpoint 'repos/o/r/releases' -Paginate -Raw
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/releases', '--jq', '.[].tag_name', '--paginate') `
        -Actual $calls[0].Arguments `
        -Message '-Paginate with -Jq leaves --slurp off, which gh refuses beside --jq'
    Assert-Equal -Expected @('api', 'repos/o/r/releases', '--paginate') -Actual $calls[1].Arguments `
        -Message 'and so does -Paginate with -Raw, which wants gh''s pages as they come'
    Assert-Equal -Expected @('v1', 'v2') -Actual $names -Message 'The jq lines come back as text'
    Assert-Equal -Expected @('v1', 'v2') -Actual $text -Message 'and so do the raw ones'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty body, which is still a body
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    Invoke-GitHubApi -Endpoint 'repos/o/r/topics' -Method PUT -Body '' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/topics', '--method', 'PUT', '--input', '-') -Actual $call.Arguments `
        -Message 'An empty -Body still tells gh to read its body from standard input'
    Assert-Equal -Expected $true -Actual $call.StdInPiped -Message 'and something is piped to it'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'which is the empty body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - pagination with a method gh will not page
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    Assert-Throws -ScriptBlock {
        Invoke-GitHubApi -Endpoint 'repos/o/r/topics' -Method put -Paginate
    } -MessageLike '*Calling repos/o/r/topics with -Paginate needs -Method GET*refuses --paginate with PUT*' `
        -Message '-Paginate with a REST method other than GET throws before gh is run'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'so gh is never called with it'

    # Act
    Invoke-GitHubApi -Endpoint 'repos/o/r/releases' -Method get -Paginate | Out-Null
    Invoke-GitHubApi -Endpoint 'graphql' -Method POST -Paginate -RawField @{ query = 'q' } | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/releases', '--method', 'GET', '--paginate', '--slurp') `
        -Actual $calls[0].Arguments `
        -Message 'A GET pages as usual'
    Assert-Equal -Expected @('api', 'graphql', '--method', 'POST', '--raw-field', 'query=q', '--paginate', '--slurp') `
        -Actual $calls[1].Arguments `
        -Message 'and so does a POST to graphql, which gh pages by cursor'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a response whose data-keyed names differ only in case, and a timestamp-like text
$fake = New-FakeGitHubCli `
    -Output @('{"description":"2026-01-02T03:04:05Z","created_at":"2026-01-02T03:04:05Z","files":{"README.md":{"size":1},"readme.md":{"size":2}}}')
try {
    # Act
    $gist = Invoke-GitHubApi -Endpoint 'gists/abc'

    # Assert
    Assert-Equal -Expected @(1, 2) -Actual @($gist.files['README.md'].size, $gist.files['readme.md'].size) `
        -Message 'Keys that differ only in case are read, not reported as "not JSON"'
    Assert-Equal -Expected '2026-01-02T03:04:05Z' -Actual $gist.description `
        -Message 'Text that looks like a timestamp stays text'
    Assert-Equal -Expected ([datetime]::new(2026, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)) -Actual $gist.created_at `
        -Message 'while a timestamp under a key ending _at is a date'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a response that is JSON but repeats a key, which is not "not JSON"
$fake = New-FakeGitHubCli -Output @('{"a":1,"a":2}')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubApi -Endpoint 'repos/o/r'
    } -MessageLike "A JSON object gives the key 'a' twice, and one of its values would be lost." `
        -Message 'A JSON object that repeats a key says so, without the advice to give -Raw'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
