#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isDraft,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query
$fake = New-FakeGitHubCli -Output @('[{"number":1,"title":"Fix"}]')
try {
    # Act
    $prs = @(Find-GitHubPullRequest -Query 'fix' -Repository 'o/r')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'prs', '--json', $fields, '--repo', 'o/r', '--', 'fix') -Actual $call.Arguments `
        -Message 'The repository filter goes through --repo, and the query comes last, after a --'
    Assert-Equal -Expected 'Fix' -Actual $prs[0].Title -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an open pull request, whose closedAt gh writes as the zero time
$fake = New-FakeGitHubCli -Output @('[{"number":1,"state":"OPEN","isDraft":false,"closedAt":"0001-01-01T00:00:00Z"}]')
try {
    # Act
    $pr = Find-GitHubPullRequest -Repository 'o/r' -State open

    # Assert
    Assert-Equal -Expected $null -Actual $pr.ClosedAt `
        -Message 'An open pull request''s ClosedAt is $null, so it does not read as closed'
    Assert-Equal -Expected $false -Actual $pr.IsDraft -Message 'and a boolean stays a boolean'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the pr-specific filters, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $prs = @(Find-GitHubPullRequest -Base 'main' -Head 'fix-1' -Draft -Merged -MergedAt '>2026-01-01' -Checks success -Review approved -ReviewRequested 'bob' -ReviewedBy 'ann' -Limit 5)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'prs', '--json', $fields, '--base', 'main', '--head', 'fix-1', '--draft', '--merged',
            '--merged-at', '>2026-01-01', '--checks', 'success', '--review', 'approved', '--review-requested', 'bob',
            '--reviewed-by', 'ann', '--limit', '5'
        ) `
        -Actual $call.Arguments `
        -Message 'Each pr-specific filter becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $prs.Count -Message 'No results writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - ready, unmerged and unlocked pull requests, which a bare switch cannot ask for
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubPullRequest -Repository 'o/r' -Draft:$false -Merged:$false -Locked:$false -Archived:$false | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'prs', '--json', $fields, '--repo', 'o/r', '--draft=false', '--merged=false', '--archived=false',
            '--', 'is:unlocked'
        ) `
        -Actual $call.Arguments `
        -Message 'A switch passed as false asks for the others in one argument, and -Locked:$false as the keyword is:unlocked, since gh ignores --locked=false for pull requests'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the filters shared with issue search, choices in another case, and dates
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubPullRequest -NoLabel -NoMilestone -NoAssignee -NoProject -Archived -Locked -State Closed -Label @('bug') -Milestone 'v1' -Project 'o/1' -Language PowerShell -Visibility @('Public') -Comments '>1' -Interactions '>1' -Reactions '>3' -Created ([datetime]'2026-01-01') -Updated '>2026-01-01' -Closed '>2026-01-01' -Match @('title') -Sort Updated -Order DESC | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'prs', '--json', $fields, '--state', 'closed', '--label', 'bug', '--no-label', '--milestone',
            'v1', '--no-milestone', '--no-assignee', '--no-project', '--project', 'o/1', '--language', 'PowerShell',
            '--visibility', 'public', '--archived', '--locked', '--comments', '>1', '--interactions', '>1',
            '--reactions', '>3', '--created', '2026-01-01', '--updated', '>2026-01-01', '--closed', '>2026-01-01',
            '--match', 'title', '--sort', 'updated', '--order', 'desc'
        ) `
        -Actual $call.Arguments `
        -Message 'Each shared filter becomes its gh flag, in declared order, a choice in lower case and a [datetime] as yyyy-MM-dd'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the people filters, several repositories, and a query with an exclusion
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubPullRequest -Query 'typo', '-label:wip' -Owner @('o1') -Repository 'a/b', 'c/d' -App 'bot' `
        -Assignee 'bob' -Mention 'ann' -TeamMention 'org/team' -Commenter 'cat' -Involves 'dog' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'prs', '--json', $fields, '--owner', 'o1', '--repo', 'a/b', '--repo', 'c/d', '--app', 'bot',
            '--assignee', 'bob', '--mentions', 'ann', '--team-mentions', 'org/team', '--commenter', 'cat', '--involves',
            'dog', '--', 'typo', '-label:wip'
        ) `
        -Actual $call.Arguments `
        -Message 'The people filters become their gh flags, each repository a --repo, and an exclusion after them is a query, not an option'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the plural names of the two single-value mention filters
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubPullRequest -Mentions 'ann' -TeamMentions 'org/team' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('search', 'prs', '--json', $fields, '--mentions', 'ann', '--team-mentions', 'org/team') `
        -Actual $call.Arguments `
        -Message '-Mentions and -TeamMentions are other names for -Mention and -TeamMention'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the author filter
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubPullRequest -Author 'me' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'prs', '--json', $fields, '--author', 'me') -Actual $call.Arguments `
        -Message '-Author becomes --author'
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
        Find-GitHubPullRequest -Query 'x' -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Query 'x' -Limit 1001
    } -MessageLike "*'Limit'*maximum allowed range of 1000*" -Message 'and so is one above 1000, which gh refuses'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Query 'x' -Review 'maybe'
    } -MessageLike "*'Review'*none,required,approved,changes_requested*" `
        -Message 'A review status gh does not have is refused, naming the ones it has'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Query 'x' -Visibility 'secret'
    } -MessageLike "*'Visibility'*public,private,internal*" `
        -Message 'A visibility GitHub does not have is refused, naming the ones it has'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Query 'x' -Sort 'stars'
    } -MessageLike "*'Sort'*comments,created,interactions,reactions,*,updated*" `
        -Message 'A sort pull requests do not have is refused, naming the ones they do'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters that would widen the search, and combinations gh refuses or ignores
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Repository '' -Label 'stale'
    } -MessageLike '-Repository was given but is blank, so it would filter nothing*Give a value, or leave -Repository off.' `
        -Message 'An empty repository is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Owner @() -Label 'stale'
    } -MessageLike '-Owner was given but is empty*' -Message 'and so is an empty list of owners'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Limit 5
    } -MessageLike 'Give a query or at least one filter*' -Message 'No query and no filter is refused'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Locked:$false -State open
    } -MessageLike 'Give a query or at least one filter*' `
        -Message 'and so are -Locked:$false, whose is:unlocked is no query of the caller''s, and -State'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Merged -Draft
    } -MessageLike 'Give a query or at least one filter*' `
        -Message 'and so are -Merged and -Draft, which still cover all of GitHub'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Checks failure -Review approved
    } -MessageLike 'Give a query or at least one filter*' `
        -Message 'and -Checks and -Review, which pick a state like -State'
    foreach ($name in 'NoLabel', 'NoMilestone', 'NoAssignee', 'NoProject') {
        $switchedOff = @{ $name = $false; Repository = 'o/r' }
        Assert-Throws -ScriptBlock {
            Find-GitHubPullRequest @switchedOff
        } -MessageLike "-${name}:`$false filters nothing*Leave -$name off instead." `
            -Message "-${name}:`$false is refused, as gh ignores its false form"
    }

    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Repository 'a/b,c/d'
    } -MessageLike "-Repository value 'a/b,c/d' holds a comma*" `
        -Message 'A comma in a repository is refused, as gh would split it'
    Assert-Throws -ScriptBlock {
        Find-GitHubPullRequest -Author 'me' -App 'bot'
    } -MessageLike '-Author and -App cannot be used together*' -Message '-Author with -App is refused, as gh refuses it'
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
        Find-GitHubPullRequest -Query 'x'
    } -MessageLike '*Searching pull requests failed*Validation Failed (HTTP 422)*' `
        -Message 'A failed search throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
