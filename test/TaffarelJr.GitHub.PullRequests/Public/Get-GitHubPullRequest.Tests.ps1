#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = & $module { Get-GitHubPullRequestField }

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one open pull request by number
$json = '{"number":12,"title":"Fix","headRefName":"fix","author":{"login":"me"},' +
'"createdAt":"2026-01-02T03:04:05Z","closedAt":null,"mergedAt":null}'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $pullRequest = Get-GitHubPullRequest -PullRequest 12 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'view', '12', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The pull request is positional and the repository goes through --repo'
    Assert-Equal -Expected 'fix' -Actual $pullRequest.HeadRefName `
        -Message 'The pull request comes back as one object with PascalCase fields'
    Assert-Equal -Expected 'me' -Actual $pullRequest.Author.Login -Message 'Nested objects are re-cased too'
    Assert-Equal -Expected ([datetime]::new(2026, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)) -Actual $pullRequest.CreatedAt `
        -Message 'A timestamp is a UTC [datetime]'
    Assert-Equal -Expected $null -Actual $pullRequest.ClosedAt -Message 'An open pull request has a $null ClosedAt'
    Assert-Equal -Expected $null -Actual $pullRequest.MergedAt -Message 'and a $null MergedAt'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current branch's pull request
$fake = New-FakeGitHubCli -Output @('{"number":1}')
try {
    # Act
    Get-GitHubPullRequest | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'view', '--json', $fields) -Actual $call.Arguments `
        -Message 'Without -PullRequest, gh uses the current branch''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one pull request, with only the fields asked for
$fake = New-FakeGitHubCli -Output @('{"number":12,"files":[{"path":"a.ps1"}],"url":"https://github.com/o/r/pull/12"}')
try {
    # Act
    $pullRequest = Get-GitHubPullRequest -PullRequest 12 -Property 'Files'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'view', '12', '--json', 'files,url,number') -Actual $call.Arguments `
        -Message '-Property asks for those fields, plus url and number'
    Assert-Equal -Expected 'a.ps1' -Actual $pullRequest.Files[0].Path -Message 'A field outside the default comes back'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing with every filter
$fake = New-FakeGitHubCli -Output @('[{"number":1},{"number":2}]')
try {
    # Act
    $pullRequests = Get-GitHubPullRequest -List -State All -Base 'main' -Head 'template-sync' -Author '@me' `
        -Assignee 'me' `
        -Label @('bug', 'needs fix') `
        -Search 'status:success' `
        -Draft:$false `
        -Limit 5 `
        -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @(
        'pr', 'list', '--json', $fields, '--state', 'all', '--base=main', '--head=template-sync', '--author=@me',
        '--assignee=me', '--label=bug', '--label=needs fix', '--search=status:success', '--draft=false', '--limit', '5',
        '--repo', 'o/r'
    ) -Actual $call.Arguments `
        -Message 'Each filter becomes its gh flag as --flag=value, one --label per label, -Draft as a three-state toggle, -State lower-cased'
    Assert-Equal -Expected 2 -Actual $pullRequests.Count -Message 'Every listed pull request is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing by a label with a comma in it, asking for two fields
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubPullRequest -List -Label 'needs fix, soon' -Property 'number,title'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'list', '--json', 'number,title,url', '--label="needs fix, soon"') `
        -Actual $call.Arguments `
        -Message 'A label holding a comma is quoted as one CSV field, so gh does not split it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing drafts only, one result
$fake = New-FakeGitHubCli -Output @('[{"number":3,"isDraft":true}]')
try {
    # Act
    $pullRequests = Get-GitHubPullRequest -List -Draft
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'list', '--json', $fields, '--draft=true') -Actual $call.Arguments `
        -Message '-Draft alone lists drafts only'
    Assert-That -Condition ($pullRequests -isnot [array]) `
        -Message 'A single listed pull request is written as that one object, not wrapped in an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no open pull requests
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $pullRequests = @(Get-GitHubPullRequest -List)

    # Assert
    Assert-Equal -Expected 0 -Actual $pullRequests.Count `
        -Message 'No pull requests writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing gh cannot read
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 401: Bad credentials') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequest -List
    } -MessageLike 'Listing pull requests failed*HTTP 401: Bad credentials*' `
        -Message 'A failed listing throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a limit that asks for nothing
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequest -List -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing by app, in a repository written with .git
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubPullRequest -List -App 'dependabot' -Repository 'o/r.git'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'list', '--json', $fields, '--app=dependabot', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message '-App becomes --app=value, and the repository loses its .git'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters given blank, and two that gh refuses together
$fake = New-FakeGitHubCli
try {
    foreach ($filter in 'Base', 'Head', 'Author', 'App', 'Assignee', 'Search') {
        $blank = @{ $filter = '' }

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Get-GitHubPullRequest -List @blank
        } -MessageLike "*-$filter was given but is blank, so it would filter nothing. Give a value, or leave -$filter off." `
            -Message "A blank -$filter is refused rather than widening the listing"
    }

    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequest -List -Label 'bug', ' '
    } -MessageLike '*-Label was given but is blank, so it would filter nothing. Give a value, or leave -Label off.' `
        -Message 'and so is a blank label in the list'
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequest -List -Author 'me' -App 'dependabot'
    } -MessageLike '-Author and -App cannot be used together: gh lists by one author or the other. Give only one.' `
        -Message '-Author and -App are refused together, as gh refuses them'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
