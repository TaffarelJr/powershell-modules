#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubIssuesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a title and a multi-line body
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/9')
try {
    # Act
    $url = New-GitHubIssue -Title 'Bug' -Body "Line 1`n`nLine 3" -Label @('bug') -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    $expected = @('issue', 'create', '--title=Bug', '--label=bug', '--body-file', $file.Path, '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The body is read from a file; the rest become their gh flags'
    Assert-Equal -Expected "Line 1`n`nLine 3" -Actual $file.Text `
        -Message 'which holds the body as given, blank lines included'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $file.Path) `
        -Message 'The file is gone once gh returns'
    Assert-Equal -Expected 'https://github.com/o/r/issues/9' -Actual $url -Message "The new issue's URL is returned"
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - bodies that a transport to gh could alter, an empty one too
foreach ($case in Get-IssueTextCase -IncludeEmpty) {
    $fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/11')
    try {
        # Act
        New-GitHubIssue -Title 'Body' -Body $case.Text | Out-Null
        $file = Get-IssueTextFile -Call @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        Assert-Equal -Expected $case.Text -Actual $file.Text -Message "A body reaches gh exactly: $($case.Name)"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other option
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/10')
try {
    # Act
    $options = @{
        Assignee  = @('@me', 'bob')
        Milestone = 'v1'
        Project   = @('Roadmap')
        Type      = 'Bug'
        Parent    = 5
        BlockedBy = @(1, '#2')
        Blocking  = @('https://github.com/o/r/issues/3')
    }
    New-GitHubIssue -Title 'Sub' -Body 'text' @options | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    $expected = @(
        'issue', 'create', '--title=Sub', '--assignee=@me', '--assignee=bob', '--project=Roadmap'
        '--milestone=v1', '--type=Bug', '--parent', '5', '--blocked-by', '1', '--blocked-by', '2'
        '--blocking', 'https://github.com/o/r/issues/3', '--body-file', $file.Path
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, one per list element'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names gh would split at a comma or fail to read
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/10')
try {
    # Act
    New-GitHubIssue -Title 'x' -Body '' -Label 'bug, urgent', 'say "hi"' -Assignee 'a,b' -Project 'Q1, Q2' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('--assignee="a,b"', '--label="bug, urgent"', '--label="say ""hi"""', '--project="Q1, Q2"')
    Assert-Equal -Expected $expected -Actual @($call.Arguments[3..6]) `
        -Message 'Labels, assignees and projects go as CSV fields, so each stays one name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - related issues given as listed issues
$listed = @(
    [PSCustomObject]@{ Number = 5; Url = 'https://github.com/o/r/issues/5' }
    [PSCustomObject]@{ Number = 6 }
)
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/10')
try {
    # Act
    New-GitHubIssue -Title 'x' -Body '' -Parent $listed[0] -BlockedBy $listed -Blocking @{ Number = 7 } | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        '--parent', 'https://github.com/o/r/issues/5'
        '--blocked-by', 'https://github.com/o/r/issues/5', '--blocked-by', '6', '--blocking', '7'
    )
    Assert-Equal -Expected $expected -Actual @($call.Arguments[3..10]) `
        -Message 'An issue object is read by its Url or Number, not by its text'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - related issues that name no issue
$refused = @(
    @{
        Options = @{ Parent = $null }
        Pattern = 'An issue was given, but it is $null.'
        Message = 'A -Parent given as $null is refused'
    }
    @{
        Options = @{ BlockedBy = @(1, $null) }
        Pattern = 'An issue was given, but it is $null.'
        Message = 'as is a $null among -BlockedBy'
    }
    @{
        Options = @{ Blocking = 'https://github.com/o/r/pull/3' }
        Pattern = '*is a pull request, not an issue*'
        Message = 'A pull request is not an issue to block'
    }
    @{
        Options = @{ Parent = '--web' }
        Pattern = "'--web' is not an issue: give its number or URL, or an issue object."
        Message = 'and a gh option is no parent'
    }
    @{
        Options = @{ Label = @('bug', ' ') }
        Pattern = '-Label has a blank element, which would send --label= with nothing after it. Give names, or leave -Label out.'
        Message = 'A blank label among others is refused, not sent as an empty one'
    }
    @{
        Options = @{ Assignee = '' }
        Pattern = '-Assignee has a blank element, which would send --assignee= with nothing after it. Give names, or leave -Assignee out.'
        Message = 'as is an empty assignee'
    }
    @{
        Options = @{ Project = @('Roadmap', '') }
        Pattern = '-Project has a blank element, which would send --project= with nothing after it. Give names, or leave -Project out.'
        Message = 'and a blank project'
    }
    @{
        Options = @{ Milestone = '' }
        Pattern = '-Milestone is blank: give a milestone''s name, or leave it out.'
        Message = 'A blank -Milestone is refused, not dropped'
    }
    @{
        Options = @{ Type = ' ' }
        Pattern = '-Type is blank: give an issue type''s name, or leave it out.'
        Message = 'as is a blank -Type'
    }
    @{
        Options = @{ Parent = '' }
        Pattern = "'' is not an issue: give its number or URL, or an issue object."
        Message = 'and a blank -Parent'
    }
    @{
        Options = @{ Blocking = @(' ') }
        Pattern = "'' is not an issue: give its number or URL, or an issue object."
        Message = 'and a blank issue among -Blocking'
    }
    @{
        Options = @{ Parent = @(1, 2) }
        Pattern = 'Give one issue at a time, not a list of 2; call once per issue.'
        Message = 'Several parents are refused, without advice to pipe them, which -Parent cannot take'
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
            New-GitHubIssue -Title 'x' -Body '' @options
        } -MessageLike $case.Pattern -Message $case.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a title that looks like an option, and a URL among other output
$fake = New-FakeGitHubCli -Output @('Creating issue in o/r', 'https://github.com/o/r/issues/12')
try {
    # Act
    $url = New-GitHubIssue -Title '--' -Body 'x' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    $expected = @('issue', 'create', '--title=--', '--body-file', $file.Path, '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'A title is joined to --title, so even -- stays the title'
    Assert-Equal -Expected 'https://github.com/o/r/issues/12' -Actual $url -Message 'Only the URL line is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the title given by position, and a repository object
$repository = [PSCustomObject]@{ Url = 'https://github.com/o/r'; NameWithOwner = 'o/r' }
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/13')
try {
    # Act
    New-GitHubIssue 'Positional' -Body 'x' -Repository $repository | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    $expected = @(
        'issue', 'create', '--title=Positional', '--body-file', $file.Path, '--repo', 'https://github.com/o/r'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The title is the one positional parameter, and a repository object is read by its Url'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a body given by position too, and a blank title
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubIssue 'Title' 'Body'
    } -MessageLike '*A positional parameter cannot be found that accepts argument ''Body''*' `
        -Message 'Only the title is positional, so a second value is refused rather than taken for whatever comes next'
    Assert-Throws -ScriptBlock {
        New-GitHubIssue -Title '' -Body 'x'
    } -MessageLike '-Title is blank, and an issue needs a title.' `
        -Message 'An empty title gets the same sentence, not PowerShell''s binding error'
    Assert-Throws -ScriptBlock {
        New-GitHubIssue -Title ' ' -Body 'x'
    } -MessageLike '-Title is blank, and an issue needs a title.' `
        -Message 'A blank title is refused, not sent as an empty one'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - GitHub refuses the issue
$fake = New-FakeGitHubCli -ErrorOutput @('could not add label: ''nope'' not found') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubIssue -Title 'Bug' -Body 'x' -Label 'nope'
    } -MessageLike '*Creating the issue failed*could not add label*' `
        -Message 'A failure throws with the message from gh'

    # Act
    $path = (Get-IssueTextFile -Call @(Get-FakeGitHubCall -Fixture $fake)[0]).Path

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $path) -Message 'and the file is gone all the same'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every option
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/9')
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        $issue = @{
            Title      = 'Flaky test'
            Body       = 'Secret text'
            Assignee   = @('@me')
            Label      = @('bug')
            Milestone  = 'v1'
            Project    = @('Roadmap')
            Type       = 'Bug'
            Parent     = 1
            BlockedBy  = @(2)
            Blocking   = @(3)
            Repository = 'o/r'
        }
        New-GitHubIssue @issue -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Create issue ''Flaky test''" on target "o/r".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the repository and the title, never the body'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns no URL'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and creates nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with no repository
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/9')
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        New-GitHubIssue -Title 'Flaky test' -Body '' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Create issue ''Flaky test''"' +
        ' on target "the current directory''s repository".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf says which repository it would be'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and creates nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a credential in the repository's URL
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        New-GitHubIssue -Title 'Flaky test' -Body '' -Repository 'https://user:SENTINEL@github.com/o/r' -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Create issue ''Flaky test''" on target "o/r".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the repository without the credential its URL carried'
    Assert-Equal -Expected 0 -Actual @($whatIf.Messages -match 'SENTINEL').Count -Message 'which no line holds'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and creates nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank title, a blank milestone, and a pull request
# as the parent
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubIssue -Title ' ' -Body 'b' -WhatIf
    } -MessageLike '-Title is blank, and an issue needs a title.' -Message '-WhatIf still refuses a blank title'
    Assert-Throws -ScriptBlock {
        New-GitHubIssue -Title 't' -Body 'b' -Milestone ' ' -WhatIf
    } -MessageLike '-Milestone is blank: give a milestone''s name, or leave it out.' -Message 'and a blank milestone'
    Assert-Throws -ScriptBlock {
        New-GitHubIssue -Title 't' -Body 'b' -Parent 'https://github.com/o/r/pull/3' -WhatIf
    } -MessageLike '*is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests*' `
        -Message 'and a pull request as the parent'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
