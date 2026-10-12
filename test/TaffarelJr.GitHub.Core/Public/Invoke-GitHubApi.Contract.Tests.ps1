#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server: what gh does with the argument
# vector is proved here, which the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$next = '<http://api.github.localhost/repos/o/r/items?page=2>; rel="next"'
$routes = [ordered]@{
    '/repos/o/r/items?per_page=100' = @{ Body = '[{"n":1},{"n":2}]'; Headers = @{ Link = $next } }
    '/repos/o/r/items?page=2'       = @{ Body = '[{"n":3}]' }
    '/repos/o/r/empty?per_page=100' = @{ Body = '[]' }
    '/repos/o/r?per_page=100'       = @{ Body = '{"full_name":"o/r"}' }
    '/repos/o/r'                    = @{ Body = '{"full_name":"o/r"}' }
    '/repos/o/r/rulesets'           = @{ Status = 201; Body = '{"id":1}' }
    '/repos/o/r/limited'            = @{ Status = 403; Body = '{"message":"API rate limit exceeded for user ID 1."}' }
    '/repos/o/r/no-rule'            = @{ Status = 404; Body = '{"message":"No rate limit rule found"}' }
}

$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a body with non-ASCII text, from a caller whose $OutputEncoding is not UTF-8
    $saved = $OutputEncoding
    $OutputEncoding = [System.Text.Encoding]::Latin1
    try {
        # Act
        Invoke-GitHubApi -Endpoint 'repos/o/r/rulesets' -Method POST -Body '{"t":"é✓"}' | Out-Null
    }
    finally {
        $OutputEncoding = $saved
    }

    $request = @(Get-FakeGitHubRequest -Server $server)[-1]
    $expected = [System.Text.Encoding]::UTF8.GetBytes('{"t":"é✓"}' + [Environment]::NewLine)

    # Assert
    Assert-Equal -Expected 'POST /repos/o/r/rulesets' -Actual "$($request.Method) $($request.Path)" `
        -Message '-Body is sent as the request body'
    Assert-Equal -Expected ([Convert]::ToHexString($expected)) -Actual ([Convert]::ToHexString($request.Body)) `
        -Message 'as UTF-8 with no byte-order mark, ended with one newline, whatever the caller''s $OutputEncoding'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a list endpoint gh pages through by its Link header
    $items = @(Invoke-GitHubApi -Endpoint 'repos/o/r/items' -Paginate)
    $paths = @(Get-FakeGitHubRequest -Server $server | Select-Object -Last 2 | ForEach-Object Path)

    # Assert
    Assert-Equal -Expected @('/repos/o/r/items?per_page=100', '/repos/o/r/items?page=2') -Actual $paths `
        -Message 'gh fetches every page'
    Assert-Equal -Expected @(1, 2, 3) -Actual @($items.ForEach('n')) `
        -Message 'and the slurped pages come back as one sequence of items, in order'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an empty list, and an endpoint that answers with one object
    $none = @(Invoke-GitHubApi -Endpoint 'repos/o/r/empty' -Paginate)
    $object = @(Invoke-GitHubApi -Endpoint 'repos/o/r' -Paginate)

    # Assert
    Assert-Equal -Expected 0 -Actual $none.Count -Message 'An empty list, which gh slurps as [[]], writes nothing'
    Assert-Equal -Expected 1 -Actual $object.Count -Message 'An object endpoint gives its one object'
    Assert-Equal -Expected 'o/r' -Actual $object[0].full_name -Message 'intact'

    #───────────────────────────────────────────────────────────────────────────
    # Act - pages projected by jq, where gh refuses --slurp
    $numbers = @(Invoke-GitHubApi -Endpoint 'repos/o/r/items' -Paginate -Jq '.[].n')

    # Assert
    Assert-Equal -Expected @('1', '2', '3') -Actual $numbers `
        -Message '-Paginate with -Jq is accepted by gh and runs over every page'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = @(Get-FakeGitHubRequest -Server $server).Count

    # Act
    $refused = Invoke-GitHubCommand -Activity 'Paging' `
        -Argument @('api', 'repos/o/r', '--paginate', '--method', 'PUT') `
        -Tolerant

    # Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubApi -Endpoint 'repos/o/r' -Method PUT -Paginate
    } -MessageLike '*needs -Method GET*' -Message '-Paginate with a REST method other than GET throws before gh runs'
    Assert-Equal -Expected 'the `--paginate` option is not supported for non-GET requests' -Actual $refused.Message `
        -Message 'which gh itself refuses with that reason, followed by usage text the message leaves out'
    Assert-Equal -Expected $before -Actual @(Get-FakeGitHubRequest -Server $server).Count `
        -Message 'and neither sends a request'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a call with variables for gh alone
    Invoke-GitHubCommand -Activity 'Reading' -Argument @('api', 'repos/o/r') -Environment @{ GH_TOKEN = 'another-fake-token' } | Out-Null
    $authorized = @(Get-FakeGitHubRequest -Server $server)[-1]

    # Assert
    Assert-Equal -Expected 'token another-fake-token' -Actual $authorized.Headers['Authorization'] `
        -Message '-Environment reaches the real gh, run as a process of its own'
    Assert-Equal -Expected 'fake-token-for-a-contract-test' -Actual $env:GH_TOKEN `
        -Message 'without changing this process''s variable'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - probes the real gh answers
    Assert-Equal -Expected $true -Actual (Test-GitHubApi -Endpoint 'repos/o/r') `
        -Message 'A probe gh answers with 200 is $true'
    Assert-Equal -Expected $false -Actual (Test-GitHubApi -Endpoint 'repos/o/r/missing') `
        -Message 'One answered with 404 is $false'
    Assert-Equal -Expected $false -Actual (Test-GitHubApi -Endpoint 'repos/o/r/no-rule') `
        -Message 'and so is a 404 whose message mentions a rate limit'
    Assert-Throws -ScriptBlock {
        Test-GitHubApi -Endpoint 'repos/o/r/limited'
    } -MessageLike 'Probing repos/o/r/limited failed (HTTP 403):*rate limit exceeded*(HTTP 403)*' `
        -Message 'while a 403 rate limit throws'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
