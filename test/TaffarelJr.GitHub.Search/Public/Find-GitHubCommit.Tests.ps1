#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'author,commit,committer,id,parents,repository,sha,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query
$fake = New-FakeGitHubCli -Output @('[{"sha":"abc","commit":{"message":"Fix"}}]')
try {
    # Act
    $commits = @(Find-GitHubCommit -Query 'fix' -Repository 'o/r')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'commits', '--json', $fields, '--repo', 'o/r', '--', 'fix') `
        -Actual $call.Arguments `
        -Message 'The repository filter goes through --repo, and the query comes last, after a --'
    Assert-Equal -Expected 'Fix' -Actual $commits[0].Commit.Message `
        -Message 'Field names are PascalCase, nested ones too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every filter, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $commits = @(Find-GitHubCommit -Owner @('o1') -Repository 'a/b', 'c/d' -Author 'me' -AuthorName 'Me' -AuthorEmail 'me@x.io' -AuthorDate '>2026-01-01' -Committer 'you' -CommitterName 'You' -CommitterEmail 'you@x.io' -CommitterDate '<2026-02-01' -Hash 'abc123' -Parent 'def456' -Tree 'fed789' -Merge -Visibility @('public', 'internal') -Sort author-date -Order asc -Limit 5)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'commits', '--json', $fields, '--owner', 'o1', '--repo', 'a/b', '--repo', 'c/d', '--author', 'me',
            '--author-name', 'Me', '--author-email', 'me@x.io', '--author-date', '>2026-01-01', '--committer', 'you',
            '--committer-name', 'You', '--committer-email', 'you@x.io', '--committer-date', '<2026-02-01', '--hash',
            'abc123', '--parent', 'def456', '--tree', 'fed789', '--merge', '--visibility', 'public', '--visibility',
            'internal', '--sort', 'author-date', '--order', 'asc', '--limit', '5'
        ) `
        -Actual $call.Arguments `
        -Message 'Each filter becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $commits.Count -Message 'No results writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - everything but merge commits
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubCommit -Merge:$false -Query '-author:bot' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'commits', '--json', $fields, '--merge=false', '--', '-author:bot') `
        -Actual $call.Arguments `
        -Message '-Merge:$false asks for the others, and an exclusion is a query, not an option'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - dates as [datetime] and [datetimeoffset], and a sort in another case
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubCommit -AuthorDate ([datetime]'2026-01-02') -CommitterDate ([datetimeoffset]'2026-03-04T00:00:00+05:00') -Sort Committer-Date | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'commits', '--json', $fields, '--author-date', '2026-01-02', '--committer-date', '2026-03-04',
            '--sort', 'committer-date'
        ) `
        -Actual $call.Arguments `
        -Message 'A [datetime] or [datetimeoffset] is the day it shows, and a sort goes in lower case'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values the parameters do not allow
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Query 'x' -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Query 'x' -Limit 1001
    } -MessageLike "*'Limit'*maximum allowed range of 1000*" -Message 'and so is one above 1000, which gh refuses'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Query 'x' -Sort 'stars'
    } -MessageLike "*'Sort'*author-date,committer-date*" `
        -Message 'A sort commits do not have is refused, naming the ones they do'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Query 'x' -Visibility 'secret'
    } -MessageLike "*'Visibility'*public,private,internal*" `
        -Message 'A visibility GitHub does not have is refused, naming the ones it has'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Repository '' -Author 'me'
    } -MessageLike '-Repository was given but is blank, so it would filter nothing*Give a value, or leave -Repository off.' `
        -Message 'An empty repository is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Owner @() -Author 'me'
    } -MessageLike '-Owner was given but is empty*' -Message 'and so is an empty list of owners'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -AuthorDate @('2026-01-01', '2026-02-01')
    } -MessageLike '-AuthorDate takes one date or date range*' -Message 'A list of dates is refused'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Repository 'o/r' `
            -CommitterDate ([datetime]::new(2026, 3, 4, 10, 30, 15, [DateTimeKind]::Utc))
    } -MessageLike '-CommitterDate got a date with a time of day*' `
        -Message 'A date with a time of day is refused, as GitHub would match it to the exact second'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Sort author-date
    } -MessageLike 'Give a query or at least one filter*' -Message 'No query and no filter is refused'
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Merge
    } -MessageLike 'Give a query or at least one filter*' `
        -Message 'and so is -Merge alone, which still covers all of GitHub'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh rejects the search
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Validation Failed (HTTP 422)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubCommit -Query 'x'
    } -MessageLike '*Searching commits failed*Validation Failed (HTTP 422)*' `
        -Message 'A failed search throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
