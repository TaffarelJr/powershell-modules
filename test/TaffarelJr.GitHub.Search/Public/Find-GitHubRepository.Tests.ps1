#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,defaultBranch,description,forksCount,fullName,hasDownloads,hasIssues,hasPages,hasProjects,hasWiki,homepage,id,isArchived,isDisabled,isFork,isPrivate,language,license,name,openIssuesCount,owner,pushedAt,size,stargazersCount,updatedAt,url,visibility,watchersCount'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query, which is a phrase
$fake = New-FakeGitHubCli -Output @('[{"fullName":"o/r","stargazersCount":10}]')
try {
    # Act
    $repos = Find-GitHubRepository -Query 'powershell module'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'repos', '--json', $fields, '--', 'powershell module') -Actual $call.Arguments `
        -Message 'The query comes last, after a --, and a value with a space stays one phrase'
    Assert-That -Condition ($repos -isnot [array]) `
        -Message 'A single result is written as that one object, not wrapped in an array'
    Assert-Equal -Expected 'o/r' -Actual $repos.FullName -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every filter, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $repos = @(Find-GitHubRepository -Owner @('o1', 'o2') -Language PowerShell -Topic @('ci') -License @('mit') -Visibility @('public') -Archived:$false -IncludeForks true -Stars '>100' -Forks '>10' -Followers '>5' -Size '<500' -GoodFirstIssues '>0' -HelpWantedIssues '>0' -NumberTopics '>1' -Created '>2026-01-01' -Updated '>2026-01-01' -Match @('name', 'readme') -Sort stars -Order desc -Limit 5)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'repos', '--json', $fields, '--owner', 'o1', '--owner', 'o2', '--language', 'PowerShell',
            '--topic', 'ci', '--license', 'mit', '--visibility', 'public', '--archived=false', '--include-forks',
            'true', '--stars', '>100', '--forks', '>10', '--followers', '>5', '--size', '<500', '--good-first-issues',
            '>0', '--help-wanted-issues', '>0', '--number-topics', '>1', '--created', '>2026-01-01', '--updated',
            '>2026-01-01', '--match', 'name', '--match', 'readme', '--sort', 'stars', '--order', 'desc', '--limit', '5'
        ) `
        -Actual $call.Arguments `
        -Message 'Every filter becomes its gh flag, and -Archived:$false is one flag=false argument'
    Assert-Equal -Expected 0 -Actual $repos.Count -Message 'No results writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - archived repositories, and a keyword with an exclusion
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubRepository -Query 'cli', '-topic:deprecated' -Archived | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'repos', '--json', $fields, '--archived', '--', 'cli', '-topic:deprecated') `
        -Actual $call.Arguments `
        -Message '-Archived alone is the bare flag, and an exclusion is a query, not an option'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - choices in another case, and a [datetime]
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubRepository -Owner 'cli' -IncludeForks Only -Updated ([datetime]'2026-01-01') -Sort Stars -Order ASC | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'repos', '--json', $fields, '--owner', 'cli', '--include-forks', 'only', '--updated',
            '2026-01-01', '--sort', 'stars', '--order', 'asc'
        ) `
        -Actual $call.Arguments `
        -Message 'A choice goes to gh in lower case, as GitHub ignores -Sort Stars, and a [datetime] as yyyy-MM-dd'
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
        Find-GitHubRepository -Query 'x' -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -Query 'x' -Limit 1001
    } -MessageLike "*'Limit'*maximum allowed range of 1000*" -Message 'and so is one above 1000, which gh refuses'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -Query 'x' -Sort 'popularity'
    } -MessageLike "*'Sort'*forks,help-wanted-issues,stars,updated*" `
        -Message 'A sort repositories cannot be ordered by is refused, naming the ones they can'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -Query 'x' -Visibility 'secret'
    } -MessageLike "*'Visibility'*public,private,internal*" `
        -Message 'A visibility GitHub does not have is refused, naming the ones it has'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -Owner @() -Topic 'powershell'
    } -MessageLike '-Owner was given but is empty*' -Message 'An empty list of owners is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -Owner '' -Topic 'powershell'
    } -MessageLike '-Owner was given but is blank, so it would filter nothing*' -Message 'and so is an empty owner'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -Topic 'a,b'
    } -MessageLike "-Topic value 'a,b' holds a comma*" `
        -Message 'A topic holding a comma is refused, as gh would split it'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -Sort stars -Order asc -Limit 3
    } -MessageLike 'Give a query or at least one filter*' -Message 'No query and no filter is refused'
    Assert-Throws -ScriptBlock {
        Find-GitHubRepository -IncludeForks true -Archived:$false
    } -MessageLike 'Give a query or at least one filter*' `
        -Message 'and so are -IncludeForks and -Archived:$false alone, which widen rather than narrow'
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
        Find-GitHubRepository -Query 'x'
    } -MessageLike '*Searching repositories failed*Validation Failed (HTTP 422)*' `
        -Message 'A failed search throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
