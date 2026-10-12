#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$assertMessage = {
    param([scriptblock]$Block, [string]$Expected, [string]$Name)
    Assert-Throws -ScriptBlock $Block -MessageLike ([WildcardPattern]::Escape($Expected)) -Message $Name
}
$notRepository = ' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
$comma = ' holds a comma, and gh would split it into two filters. Give each value on its own' +
" (-{0} 'a', 'b'); for one value that holds a comma, put the qualifier in -Query instead, quoted," +
" such as 'label:`"a,b`"'."
$env:GH_HOST = $null

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every message that shows a value it was given, with no gh run
$messages = @(
    @{
        Block = { Find-GitHubCode -Repository 'https://user:SENTINEL@ghe.example.com/o/r' }
        Expected = "'https://***@ghe.example.com/o/r' is on ghe.example.com, but GH_HOST is not set, so it is" +
        ' compared with github.com: set GH_HOST to ghe.example.com to search there.'
        Name = 'ConvertTo-GitHubSearchRepository, for a repository on another host'
    }
    @{
        Block = {
            Find-GitHubCode -Repository ([PSCustomObject]@{ Url = 'https://user:SENTINEL@ghe.example.com/o/r' })
        }
        Expected = "'https://***@ghe.example.com/o/r' is on ghe.example.com, but GH_HOST is not set, so it is" +
        ' compared with github.com: set GH_HOST to ghe.example.com to search there.'
        Name = 'and for a repository object'
    }
    @{
        Block = { Find-GitHubCode -Repository 'user:SENTINEL@ghe.example.com:o/r' }
        Expected = "'***@ghe.example.com:o/r'$notRepository"
        Name = 'for a USER@HOST: form'
    }
    @{
        Block = { Find-GitHubCode -Repository 'https://user:SENTINEL@ghe.example.com/api/v3/repos/o/r' }
        Expected = "'https://***@ghe.example.com/api/v3/repos/o/r'$notRepository"
        Name = 'for a REST URL'
    }
    @{
        Block = { Find-GitHubCode -Repository 'https://user@SENTINEL@ghe.example.com/o/r' }
        Expected = "'https://***@ghe.example.com/o/r'$notRepository"
        Name = 'for user information that holds an @, which would put a part of it in the host'
    }
    @{
        Block = { Find-GitHubCode -Repository 'https://user:SENTINEL@ghe.example.com/o/r x' }
        Expected = "'https://***@ghe.example.com/o/r x'$notRepository"
        Name = 'and for text holding a space'
    }
    @{
        Block = { Find-GitHubCode -Repository 'https://user:SENTINEL@h.example/o,r' }
        Expected = "-Repository value 'https://***@h.example/o,r'" + ($comma -f 'Repository')
        Name = 'ConvertTo-GitHubSearchArgument, for a repository holding a comma'
    }
    @{
        Block = { Find-GitHubIssue -Label 'user:SENTINEL@h.example,x' }
        Expected = "-Label value '***@h.example,x'" + ($comma -f 'Label')
        Name = 'and for a label holding one'
    }
    @{
        Block = { Find-GitHubCode -Owner 'user:SENTINEL@h.example,x' }
        Expected = "-Owner value '***@h.example,x'" + ($comma -f 'Owner')
        Name = 'and for an owner holding one'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($case in $messages) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - GH_HOST naming a host with a credential in it
$fake = New-FakeGitHubCli
$env:GH_HOST = 'user:SENTINEL@ghe.example.com'
try {
    $expected = "'ghe2.example.com/o/r' is on ghe2.example.com, but GH_HOST names ***@ghe.example.com: set GH_HOST" +
    ' to ghe2.example.com to search there.'

    # Act / Assert
    & $assertMessage {
        Find-GitHubCode -Repository 'ghe2.example.com/o/r'
    } $expected 'ConvertTo-GitHubSearchRepository shows no credential in the GH_HOST it compares with'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    $env:GH_HOST = $null
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing a URL with a credential on its error stream
$shownQuery = 'https://***@h.example/x'
$shownFailure = 'fatal: https://***@h.example/x forbidden'
$failures = @(
    @{
        Block = { Find-GitHubCode -Query 'https://user:SENTINEL@h.example/x' }
        Start = 'Searching code failed: gh search code --json '
        Name = 'Find-GitHubCode'
    }
    @{
        Block = { Find-GitHubCommit -Query 'https://user:SENTINEL@h.example/x' }
        Start = 'Searching commits failed: gh search commits --json '
        Name = 'Find-GitHubCommit'
    }
    @{
        Block = { Find-GitHubIssue -Query 'https://user:SENTINEL@h.example/x' }
        Start = 'Searching issues failed: gh search issues --json '
        Name = 'Find-GitHubIssue'
    }
    @{
        Block = { Find-GitHubPullRequest -Query 'https://user:SENTINEL@h.example/x' }
        Start = 'Searching pull requests failed: gh search prs --json '
        Name = 'Find-GitHubPullRequest'
    }
    @{
        Block = { Find-GitHubRepository -Query 'https://user:SENTINEL@h.example/x' }
        Start = 'Searching repositories failed: gh search repos --json '
        Name = 'Find-GitHubRepository'
    }
)
$fake = New-FakeGitHubCli -ErrorOutput @('fatal: https://user:SENTINEL@h.example/x forbidden') -ExitCode 1
try {
    # Act / Assert
    foreach ($case in $failures) {
        $like = [WildcardPattern]::Escape($case.Start) + '*' +
        [WildcardPattern]::Escape(" -- $shownQuery (exit 1)`n$shownFailure")
        Assert-Throws -ScriptBlock $case.Block -MessageLike $like `
            -Message "$($case.Name) shows no credential, in the query it passed to gh or in what gh printed"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that answers with something that is not JSON
$notJson = @(
    @{ Block = { Find-GitHubCode -Query 'x' }; Name = 'Find-GitHubCode' }
    @{ Block = { Find-GitHubCommit -Query 'x' }; Name = 'Find-GitHubCommit' }
    @{ Block = { Find-GitHubIssue -Query 'x' }; Name = 'Find-GitHubIssue' }
    @{ Block = { Find-GitHubPullRequest -Query 'x' }; Name = 'Find-GitHubPullRequest' }
    @{ Block = { Find-GitHubRepository -Query 'x' }; Name = 'Find-GitHubRepository' }
)
$fake = New-FakeGitHubCli -Output @('moved to https://user:SENTINEL@h.example/x')
try {
    $expected = "gh's output is not valid JSON, starting 'moved to https://***@h.example/x': 'm' is an invalid" +
    ' start of a value. LineNumber: 0 | BytePositionInLine: 0.'

    # Act / Assert
    foreach ($case in $notJson) {
        & $assertMessage $case.Block $expected "$($case.Name) shows no credential in output it cannot read"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
