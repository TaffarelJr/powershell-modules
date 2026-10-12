#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$env:GH_HOST = $null
$fields = 'assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query
$fake = New-FakeGitHubCli -Output @('[{"number":1,"title":"Bug"}]')
try {
    # Act
    $issues = @(Find-GitHubIssue -Query 'crash' -Repository 'o/r')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'issues', '--json', $fields, '--repo', 'o/r', '--', 'crash') `
        -Actual $call.Arguments `
        -Message 'The repository filter goes through --repo, and the query comes last, after a --'
    Assert-Equal -Expected 'Bug' -Actual $issues[0].Title -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filter values that start with a dash, as a label or an author name may
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -Repository 'o/r' -Author '-y' -Label '-x', 'bug' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'search', 'issues', '--json', $fields, '--repo', 'o/r', '--author', '-y', '--label', '-x', '--label', 'bug'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'A value that starts with a dash is the argument after its flag, which gh reads as the value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an open issue, whose closedAt gh writes as the zero time
$fake = New-FakeGitHubCli `
    -Output @('[{"number":1,"state":"OPEN","closedAt":"0001-01-01T00:00:00Z","createdAt":"2026-01-02T03:04:05Z"}]')
try {
    # Act
    $issue = Find-GitHubIssue -Repository 'o/r' -State open

    # Assert
    Assert-Equal -Expected $null -Actual $issue.ClosedAt `
        -Message 'An open issue''s ClosedAt is $null, so it does not read as closed'
    Assert-Equal -Expected ([datetime]::new(2026, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)) -Actual $issue.CreatedAt `
        -Message 'while a real timestamp is a [datetime]'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several repositories and owners
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -Repository 'a/b', 'c/d' -Owner 'x', 'y' -Label 'bug' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'issues', '--json', $fields, '--owner', 'x', '--owner', 'y', '--repo', 'a/b', '--repo', 'c/d',
            '--label', 'bug'
        ) `
        -Actual $call.Arguments `
        -Message 'Each repository is a --repo of its own, which gh ORs, like each owner'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories as objects and URLs, such as another search's results
$fake = New-FakeGitHubCli -Output @('[]')
$found = [pscustomobject]@{ Number = 1; Repository = [pscustomobject]@{ Name = 'cli'; NameWithOwner = 'cli/cli' } }
$listed = [pscustomobject]@{ Url = 'https://github.com/o/r'; NameWithOwner = 'o/r' }
try {
    # Act
    Find-GitHubIssue -Query 'crash' -Repository $found.Repository, $listed, 'https://github.com/a/b.git' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'issues', '--json', $fields, '--repo', 'cli/cli', '--repo', 'o/r', '--repo', 'a/b', '--', 'crash'
        ) `
        -Actual $call.Arguments `
        -Message 'A repository object or URL reaches gh as OWNER/REPO, never as its text form'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories gh's search cannot find
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Repository 'cli'
    } -MessageLike "'cli' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL." `
        -Message 'A bare name is refused'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Repository 'https://ghe.example.com/o/r'
    } -MessageLike "'https://ghe.example.com/o/r' is on ghe.example.com*GH_HOST*" `
        -Message 'and so is a repository on another host'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Repository $null
    } -MessageLike '-Repository was given, but it is $null, so it would filter nothing*leave -Repository off.' `
        -Message 'and a repository given as $null, which would widen the search'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the switch filters, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $issues = @(Find-GitHubIssue -Repository 'o/r' -NoLabel -NoMilestone -NoAssignee -NoProject -Archived:$false -Locked -IncludePullRequests -State open -Limit 5)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'issues', '--json', $fields, '--repo', 'o/r', '--state', 'open', '--no-label', '--no-milestone',
            '--no-assignee', '--no-project', '--archived=false', '--locked', '--include-prs', '--limit', '5'
        ) `
        -Actual $call.Arguments `
        -Message 'Each switch filter becomes its gh flag, and one passed as false is flag=false in one argument'
    Assert-Equal -Expected 0 -Actual $issues.Count -Message 'No results writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same filters pointing the other way
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -Repository 'o/r' -Archived -Locked:$false | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'issues', '--json', $fields, '--repo', 'o/r', '--archived', '--locked=false') `
        -Actual $call.Arguments `
        -Message '-Archived alone is the bare flag, and -Locked:$false says so in one argument'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the remaining string/range filters
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -App 'dependabot' -Assignee 'bob' -Mention 'ann' -TeamMention 'org/team' -Commenter 'cat' `
        -Involves 'dog' -Label @('bug') -Milestone 'v1' -Project 'o/1' -Language PowerShell -Visibility @('public') `
        -Comments '>5' -Interactions '>10' -Reactions '>2' -Created '>2026-01-01' -Updated '>2026-01-01' `
        -Closed '>2026-01-01' -Match @('title', 'body') -Sort created -Order asc | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'issues', '--json', $fields, '--app', 'dependabot', '--assignee', 'bob', '--mentions', 'ann',
            '--team-mentions', 'org/team', '--commenter', 'cat', '--involves', 'dog', '--label', 'bug', '--milestone',
            'v1', '--project', 'o/1', '--language', 'PowerShell', '--visibility', 'public', '--comments', '>5',
            '--interactions', '>10', '--reactions', '>2', '--created', '>2026-01-01', '--updated', '>2026-01-01',
            '--closed', '>2026-01-01', '--match', 'title', '--match', 'body', '--sort', 'created', '--order', 'asc'
        ) `
        -Actual $call.Arguments `
        -Message 'Every remaining filter becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the plural names of the two single-value mention filters
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -Mentions 'ann' -TeamMentions 'org/team' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('search', 'issues', '--json', $fields, '--mentions', 'ann', '--team-mentions', 'org/team') `
        -Actual $call.Arguments `
        -Message '-Mentions and -TeamMentions are other names for -Mention and -TeamMention'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a semantic search, choices in another case, and a [datetime]
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -Query 'login fails' -Author 'me' -State Open -SearchType Semantic -Created ([datetime]'2026-01-01') | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'issues', '--json', $fields, '--author', 'me', '--state', 'open', '--created', '2026-01-01',
            '--search-type', 'semantic', '--', 'login fails'
        ) `
        -Actual $call.Arguments `
        -Message 'A choice goes to gh in lower case, and a [datetime] as yyyy-MM-dd, which GitHub accepts'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several keywords, a phrase, and an exclusion
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -Query 'broken feature', 'label:bug', '-label:wontfix' -Repository 'o/r' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'issues', '--json', $fields, '--repo', 'o/r', '--', 'broken feature', 'label:bug',
            '-label:wontfix'
        ) `
        -Actual $call.Arguments `
        -Message 'Each value is one keyword, so a phrase stays whole and an exclusion is not read as an option'
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
        Find-GitHubIssue -Query 'x' -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query 'x' -Limit 1001
    } -MessageLike "*'Limit'*maximum allowed range of 1000*" -Message 'and so is one above 1000, which gh refuses'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query 'x' -State 'merged'
    } -MessageLike "*'State'*open,closed*" -Message 'A state an issue cannot be in is refused, naming the ones it can'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query 'x' -Visibility 'secret'
    } -MessageLike "*'Visibility'*public,private,internal*" `
        -Message 'A visibility GitHub does not have is refused, naming the ones it has'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query 'x' -Sort 'stars'
    } -MessageLike "*'Sort'*comments,created,interactions,reactions,*,updated*" `
        -Message 'A sort issues do not have is refused, naming the ones they do'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query 'x' -Created ([datetime]::new(2026, 10, 4, 9, 33, 17))
    } -MessageLike '-Created got a date with a time of day, which GitHub matches to the exact second*' `
        -Message 'A [datetime] with a time of day, as Get-Date gives, is refused rather than match one second'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters that would widen the search to all of GitHub
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Repository '' -Label 'stale'
    } -MessageLike '-Repository was given but is blank, so it would filter nothing*Give a value, or leave -Repository off.' `
        -Message 'An empty repository is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Owner @() -Label 'stale'
    } -MessageLike '-Owner was given but is empty*' -Message 'and so is an empty list of owners'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Author ' '
    } -MessageLike '-Author was given but is blank, so it would filter nothing*leave -Author off.' `
        -Message 'and a blank author'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query ' '
    } -MessageLike '-Query holds a blank keyword*' -Message 'A whitespace keyword is refused'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue
    } -MessageLike 'Give a query or at least one filter*' -Message 'No query and no filter is refused'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Limit 5 -Sort created -Order asc
    } -MessageLike 'Give a query or at least one filter*' -Message 'and so are options that only shape the results'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - combinations gh refuses or ignores
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($name in 'NoLabel', 'NoMilestone', 'NoAssignee', 'NoProject', 'IncludePullRequests') {
        $switchedOff = @{ $name = $false; Repository = 'o/r' }
        Assert-Throws -ScriptBlock {
            Find-GitHubIssue @switchedOff
        } -MessageLike "-${name}:`$false filters nothing*Leave -$name off instead." `
            -Message "-${name}:`$false is refused, as gh ignores its false form"
    }

    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Label 'a,b'
    } -MessageLike "-Label value 'a,b' holds a comma*" `
        -Message 'A label holding a comma is refused, as gh would split it'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Author 'me' -App 'bot'
    } -MessageLike '-Author and -App cannot be used together*' -Message '-Author with -App is refused, as gh refuses it'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query 'x' -SearchType semantic -Sort created -Order asc
    } -MessageLike '-SearchType semantic and -Sort, -Order cannot be used together: *lexical search only. Give only one.' `
        -Message 'A semantic search with -Sort and -Order is refused, naming both'
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Query 'x' -SearchType Hybrid -IncludePullRequests
    } -MessageLike '-SearchType hybrid and -IncludePullRequests cannot be used together*' `
        -Message 'and a hybrid one with -IncludePullRequests'
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
        Find-GitHubIssue -Query 'x'
    } -MessageLike '*Searching issues failed*Validation Failed (HTTP 422)*' `
        -Message 'A failed search throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
