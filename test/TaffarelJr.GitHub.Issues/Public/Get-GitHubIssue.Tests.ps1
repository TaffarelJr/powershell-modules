#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = & $module { Get-GitHubIssueField }

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one issue by number
$fake = New-FakeGitHubCli -Output @('{"number":12,"title":"Bug","isPinned":false}')
try {
    # Act
    $issue = Get-GitHubIssue -Issue 12 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'view', '12', '--json', $fields, '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The issue is positional and the repository goes through --repo'
    Assert-Equal -Expected 'Bug' -Actual $issue.Title `
        -Message 'The issue comes back as one object with PascalCase fields'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the fields named, including one the default leaves out
$fake = New-FakeGitHubCli -Output @('{"number":12,"comments":[],"url":"https://github.com/o/r/issues/12"}')
try {
    # Act
    Get-GitHubIssue -Issue 12 -Property 'number', 'comments' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'view', '12', '--json', 'number,comments,url')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message '-Property replaces the default fields, with url always added'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing with every filter but -App, which gh takes only without
# -Author
$fake = New-FakeGitHubCli -Output @('[{"number":1},{"number":2}]')
try {
    # Act
    $filters = @{
        State      = 'all'
        Author     = '@me'
        Assignee   = 'me'
        Mention    = 'bob'
        Label      = @('bug', 'p1')
        Milestone  = 'v1'
        Type       = 'Bug'
        Search     = 'status:open'
        Limit      = 5
        Repository = 'o/r'
    }
    $issues = Get-GitHubIssue -List @filters
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'issue', 'list', '--json', $fields, '--state', 'all', '--author=@me'
        '--assignee=me', '--mention=bob', '--milestone=v1', '--type=Bug', '--search=status:open'
        '--label=bug', '--label=p1', '--limit', '5', '--repo', 'o/r'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Each filter becomes its gh flag, one --label per label'
    Assert-Equal -Expected 2 -Actual $issues.Count -Message 'Every listed issue is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - issues opened by an app
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubIssue -List -App 'dependabot' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'list', '--json', $fields, '--app=dependabot') -Actual $call.Arguments `
        -Message '-App becomes --app'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters that gh would split at a comma or read as an option
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubIssue -List -Label 'bug, urgent', 'say "hi"' -Assignee 'a,b' -Search '--' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'issue', 'list', '--json', $fields, '--assignee=a,b', '--search=--', '--label="bug, urgent"'
        '--label="say ""hi"""'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Labels go as CSV fields; --assignee, which gh never splits, as it is'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the mentioned user named as Find-GitHubIssue names it
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubIssue -List -Mentions 'bob' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'list', '--json', $fields, '--mention=bob') -Actual $call.Arguments `
        -Message '-Mentions is another name for -Mention'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a state in a casing other than gh's
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubIssue -List -State 'Open' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'list', '--json', $fields, '--state', 'open')
    Assert-Equal -Expected $expected -Actual $call.Arguments -Message '-State reaches gh lower-cased'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing of a repository given as a repository object
$repository = [PSCustomObject]@{ Url = 'https://ghe.example.com/o/r'; NameWithOwner = 'o/r' }
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubIssue -List -Repository $repository | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'list', '--json', $fields, '--repo', 'https://ghe.example.com/o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'A listing reads a repository object by its Url, host included'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters given but blank, which would widen the listing, and a
# pair gh refuses together
$refused = @(
    foreach ($name in 'Author', 'App', 'Assignee', 'Mention', 'Milestone', 'Type', 'Search') {
        @{
            Options = @{ $name = ' ' }
            Pattern = "*-$name was given but is blank, so it would filter nothing. Give a value, or leave -$name off."
            Message = "A blank -$name is refused, not dropped"
        }
    }
    @{
        Options = @{ Label = @('bug', '') }
        Pattern = '*-Label was given but is blank, so it would filter nothing. Give a value, or leave -Label off.'
        Message = 'as is a blank label among others'
    }
    @{
        Options = @{ Author = '' }
        Pattern = '*-Author was given but is blank, so it would filter nothing. Give a value, or leave -Author off.'
        Message = 'and an empty one'
    }
    @{
        Options = @{ Author = 'a'; App = 'b' }
        Pattern = '-Author and -App cannot be used together: gh lists by one author or the other. Give only one.'
        Message = '-Author and -App are refused together, as gh refuses them'
    }
    @{
        Options = @{ Repository = $null }
        Pattern = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message = 'A -Repository given as $null is refused, not taken for the current directory''s'
    }
)
$fake = New-FakeGitHubCli
try {
    foreach ($case in $refused) {
        $options = $case.Options

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Get-GitHubIssue -List @options
        } -MessageLike $case.Pattern -Message $case.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing of chosen fields, none of them url
$fake = New-FakeGitHubCli -Output @('[{"number":1,"title":"A","url":"https://github.com/o/r/issues/1"}]')
try {
    # Act
    Get-GitHubIssue -List -Property 'title' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'list', '--json', 'title,number,url')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message '-Property applies to a listing too, still with number and url'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a single listed issue
$fake = New-FakeGitHubCli -Output @('[{"number":1}]')
try {
    # Act
    $issues = Get-GitHubIssue -List

    # Assert
    Assert-That -Condition ($issues -is [PSCustomObject] -and $issues -isnot [array]) `
        -Message 'A single listed issue is written as that one object, not wrapped in an array'
    Assert-Equal -Expected 1 -Actual $issues.Number -Message 'and it is the issue listed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no issues at all
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $issues = @(Get-GitHubIssue -List)

    # Assert
    Assert-Equal -Expected 0 -Actual $issues.Count -Message 'No issues writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a limit that asks for nothing, and fields that name nothing
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubIssue -List -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Get-GitHubIssue -List -Property ' , '
    } -MessageLike '*-Property names no field*' `
        -Message 'A -Property naming no field is refused, not taken for the default'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
