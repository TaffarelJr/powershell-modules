#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the table hands to Assert-Throws, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$url = 'https://user:SENTINEL@ghe.example.com/o/r'
$shown = 'https://***@ghe.example.com/o/r'
$assertMessage = {
    param([scriptblock]$Block, [string]$Expected, [string]$Name)
    Assert-Throws -ScriptBlock $Block -MessageLike ([WildcardPattern]::Escape($Expected)) -Message $Name
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every message that shows a value it was given, with no gh run
$messages = @(
    @{
        Block = { Assert-GitHubHostname -Hostname 'user:SENTINEL@ghe.example.com' }
        Expected = "'***@ghe.example.com' is not a host name: give it bare, such as github.com - labels of letters," +
        ' digits, dashes, and underscores joined by single dots, none starting or ending with a dash, and no' +
        ' scheme, port, path, space, or trailing dot - or leave -Hostname out for the default host.'
        Name = 'Assert-GitHubHostname'
    }
    @{
        Block = {
            Assert-GitHubSameRepository -Item "'$url/issues/1'" -Origin "$url/issues/1" `
                -Repository 'https://v:SENTINEL@ghe.example.com/o/other'
        }
        Expected = "'$shown/issues/1' is in ghe.example.com/o/r, but -Repository names" +
        ' https://***@ghe.example.com/o/other: give one or the other.'
        Name = 'Assert-GitHubSameRepository, in the item and in -Repository'
    }
    @{
        Block = { ConvertTo-GitHubRepositoryReference -Repository 'user:SENTINEL@ghe.example.com:o/r' }
        Expected = "'***@ghe.example.com:o/r' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
        Name = 'ConvertTo-GitHubRepositoryReference, for a USER@HOST: form'
    }
    @{
        Block = { ConvertTo-GitHubRepositoryReference -Repository "$url x" }
        Expected = "'$shown x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
        Name = 'and for text holding a space'
    }
    @{
        Block = { Resolve-GitHubRepositoryArgument -Value "$url x" -Given $true }
        Expected = "'$shown x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
        Name = 'Resolve-GitHubRepositoryArgument, for its value'
    }
    @{
        Block = { Resolve-GitHubRepositoryArgument -Value $null -Given $true -Omitted "the repository at $url" }
        Expected = "-Repository was given, but it is `$null - leave it out to use the repository at $shown."
        Name = 'and for -Omitted'
    }
    @{
        Block = { Resolve-GitHubItemReference -Item "$url/issues/x" -Kind Issue }
        Expected = "'$shown/issues/x' is not an issue: a URL must end in /OWNER/REPO/issues/NUMBER."
        Name = 'Resolve-GitHubItemReference, for a URL that names no item'
    }
    @{
        Block = { Resolve-GitHubItemReference -Item "$url/pull/1" -Kind Issue }
        Expected = "'$shown/pull/1' is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests for it."
        Name = 'for one of the other kind'
    }
    @{
        Block = { Resolve-GitHubItemReference -Item "$url/issues/1" -Kind Issue -Repository 'o/other' }
        Expected = "'$shown/issues/1' is in ghe.example.com/o/r, but -Repository names o/other:" +
        ' give one or the other.'
        Name = 'for one from another repository'
    }
    @{
        Block = { Resolve-GitHubItemReference -Item 'u:SENTINEL@h o' -Kind PullRequest }
        Expected = "'***@h o' is not a pull request: give its number, URL, or branch name, or a pull request object."
        Name = 'for unreadable text'
    }
    @{
        Block = { Resolve-GitHubItemReference -Item ([PSCustomObject]@{ Number = 'u:SENTINEL@h' }) -Kind Issue }
        Expected = "'***@h' is not an issue number: an object's Number must be a whole number of 1 to 10 digits."
        Name = 'and for an object''s Number'
    }
    @{
        Block = { Resolve-GitHubInputFile -Path 'SENTINEL@ghe.example.com/notes.md' -Name 'NotesFile' }
        Expected = "-NotesFile '***@ghe.example.com/notes.md' is not a file."
        Name = 'Resolve-GitHubInputFile'
    }
    @{
        Block = { Resolve-GitHubPath -Path 'Env:/user:SENTINEL@h.example/x' }
        Expected = "'***@h.example/x' is not a file system path (it is on the Environment provider)," +
        ' so gh cannot use it.'
        Name = 'Resolve-GitHubPath'
    }
    @{
        Block = { ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ 'u:SENTINEL@h[x' = 1 } }
        Expected = "Field key '***@h[x' holds '=', '[' or ']', which gh reads as part of its key[name]=value syntax" +
        ' - send it with -Body.'
        Name = 'ConvertTo-GitHubFieldArgument, for a key'
    }
    @{
        Block = { ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ 'u:SENTINEL@h' = @{} } }
        Expected = "Field '***@h' is an empty hashtable, which gh's fields cannot express - send it with -Body."
        Name = 'for an empty hashtable'
    }
    @{
        Block = { ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ 'u:SENTINEL@h' = @(@{ a = 1 }) } }
        Expected = "Field '***@h' holds a list of objects or lists, which gh's fields cannot express - send it with -Body."
        Name = 'for a list of objects'
    }
    @{
        Block = { ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ 'u:SENTINEL@h' = [object]::new() } }
        Expected = "Field '***@h' holds a Object, which gh's fields cannot express - send it with -Body."
        Name = 'and for a value it cannot send'
    }
    @{
        Block = { ConvertFrom-GitHubJson -Line '{"u:SENTINEL@h":1,"u:SENTINEL@h":2}' }
        Expected = "A JSON object gives the key '***@h' twice, and one of its values would be lost."
        Name = 'ConvertFrom-GitHubJson, for a key given twice'
    }
    @{
        Block = { ConvertFrom-GitHubJson -Line "see $url {" }
        Expected = "gh's output is not valid JSON, starting 'see $shown {': 's' is an invalid start of a value." +
        ' LineNumber: 0 | BytePositionInLine: 0.'
        Name = 'and for output that is not JSON'
    }
    @{
        Block = { ConvertFrom-GitHubJson -Line ("$url " + ('x' * 200)) }
        Expected = "gh's output is not valid JSON, starting '$shown $('x' * 88)...': 'h' is an invalid start of a" +
        ' value. LineNumber: 0 | BytePositionInLine: 0.'
        Name = 'even when the start shown is cut short'
    }
    @{
        Block = { Invoke-GitHubApi -Endpoint $url -Method PUT -Paginate }
        Expected = "Calling $shown with -Paginate needs -Method GET: gh fetches further pages only for a GET of a" +
        ' REST endpoint (or for graphql), and refuses --paginate with PUT.'
        Name = 'Invoke-GitHubApi, for -Paginate'
    }
    @{
        Block = { Invoke-GitHubApi -Endpoint "-$url" }
        Expected = "Cannot validate argument on parameter 'Endpoint'. '-$shown' starts with '-', which gh would read" +
        ' as an option.'
        Name = 'and for an endpoint starting with a dash'
    }
    @{
        Block = { Test-GitHubApi -Endpoint "-$url" }
        Expected = "Cannot validate argument on parameter 'Endpoint'. '-$shown' starts with '-', which gh would read" +
        ' as an option.'
        Name = 'Test-GitHubApi, for an endpoint starting with a dash'
    }
    @{
        Block = {
            Assert-GitHubPollRead -Result @{ Ok = $false; ExitCode = 1; Message = "HTTP 403: $url" } -Action "read $url"
        }
        Expected = "Could not read $shown (HTTP 403):`nHTTP 403: $shown"
        Name = 'Assert-GitHubPollRead'
    }
)

# Act / Assert
foreach ($case in $messages) {
    & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential"
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - the timeout message, which is returned, not thrown
Assert-Equal -Expected "Run 7 of $shown was still queued after 1 s. Give a longer -TimeoutSeconds to wait more." `
    -Actual (Get-GitHubTimeoutMessage -Subject "Run 7 of $url was still queued after 1 s.") `
    -Message 'Get-GitHubTimeoutMessage shows no credential'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing the URL on stdout and stderr
$fake = New-FakeGitHubCli -Output @("cloning $url") `
    -ErrorOutput @("fatal: unable to access '$url/': The requested URL returned error: 403") `
    -ExitCode 1
try {
    $expected = "Cloning $shown failed: gh repo clone $shown --header 'X-Note: $shown' --repo $shown (exit 1)`n" +
    "cloning $shown`nfatal: unable to access '$shown/': The requested URL returned error: 403"

    # Act / Assert
    & $assertMessage {
        Invoke-GitHubCommand -Activity "Cloning $url" -Argument @('repo', 'clone', $url, '--header', "X-Note: $url") `
            -Repository $url
    } $expected 'Invoke-GitHubCommand shows no credential: not in the activity, an argument, --repo, or a printed line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh api failing on an endpoint that is a URL with a credential
$fake = New-FakeGitHubCli -ErrorOutput @("Get `"$url`": Forbidden (HTTP 403)") -ExitCode 1
try {
    $expected = "Calling $shown failed: gh api $shown --header 'X-Note: ***' (exit 1)`n" +
    "Get `"$shown`": Forbidden (HTTP 403)"

    # Act / Assert
    & $assertMessage {
        Invoke-GitHubApi -Endpoint $url -Header @{ 'X-Note' = "$url/note" }
    } $expected 'Invoke-GitHubApi shows no credential in the endpoint, a header, or what gh printed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh api answering with something that is not JSON
$fake = New-FakeGitHubCli -Output @("moved to $url")
try {
    $expected = "The response from $shown is not JSON - give -Raw to read it as text. gh's output is not valid" +
    " JSON, starting 'moved to $shown': 'm' is an invalid start of a value. LineNumber: 0 | BytePositionInLine: 0."

    # Act / Assert
    & $assertMessage {
        Invoke-GitHubApi -Endpoint $url
    } $expected 'and none in the response it could not parse'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails a probe
$fake = New-FakeGitHubCli -ErrorOutput @("gh: Forbidden $url (HTTP 403)") -ExitCode 1
try {
    # Act / Assert
    & $assertMessage {
        Test-GitHubApi -Endpoint $url
    } "Probing $shown failed (HTTP 403):`ngh: Forbidden $shown (HTTP 403)" 'Test-GitHubApi shows no credential'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a machine with no gh on its PATH
$savedPath = $env:PATH
$env:PATH = ''
try {
    # Act / Assert
    & $assertMessage {
        Invoke-GitHubCommand -Activity "Cloning $url" -Argument @('repo', 'clone', $url)
    } "Cloning $shown failed: gh was not found on PATH." 'nor when gh cannot be found'
}
finally {
    $env:PATH = $savedPath
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails after printing a token on its own, as --show-token does
$token = 'ghp_' + ('A' * 36)
$fake = New-FakeGitHubCli -Output @("Token: $token") -ErrorOutput @("gh: Forbidden $token (HTTP 403)") -ExitCode 1
try {
    # Act / Assert
    & $assertMessage {
        Invoke-GitHubCommand -Activity "Showing $token" -Argument @('auth', 'status', '--show-token', $token)
    } "Showing *** failed: gh auth status --show-token *** (exit 1)`nToken: ***`ngh: Forbidden *** (HTTP 403)" `
        'Invoke-GitHubCommand shows no token that stands alone: not in the activity, an argument, or a printed line'

    # Act / Assert
    & $assertMessage {
        Test-GitHubApi -Endpoint 'user'
    } "Probing user failed (HTTP 403):`nToken: ***`ngh: Forbidden *** (HTTP 403)" `
        'Test-GitHubApi shows no token that stands alone'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh api answering with a token where JSON should be
$fake = New-FakeGitHubCli -Output @("moved to $token")
try {
    $expected = 'The response from user is not JSON - give -Raw to read it as text. gh''s output is not valid JSON,' +
    " starting 'moved to ***': 'm' is an invalid start of a value. LineNumber: 0 | BytePositionInLine: 0."

    # Act / Assert
    & $assertMessage {
        Invoke-GitHubApi -Endpoint 'user'
    } $expected 'and none in the response it could not parse'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
