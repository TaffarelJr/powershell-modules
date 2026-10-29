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
# Arrange - a title and body, plus a label swap
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Title 'Renamed' -Body 'New body' -AddLabel @('needs fix') -RemoveLabel @('ready') `
        -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    $expected = @(
        'issue', 'edit', '12', '--title=Renamed', '--add-label=needs fix', '--remove-label=ready'
        '--body-file', $file.Path, '--repo', 'o/r'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The body is read from a file; the rest become their gh flags'
    Assert-Equal -Expected 'New body' -Actual $file.Text -Message 'which holds the body as given'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $file.Path) `
        -Message 'The file is gone once gh returns'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - bodies that a transport to gh could alter, an empty one too,
# which clears the body
foreach ($case in Get-IssueTextCase -IncludeEmpty) {
    $fake = New-FakeGitHubCli
    try {
        # Act
        Set-GitHubIssue -Issue 12 -Body $case.Text
        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
        $file = Get-IssueTextFile -Call $call

        # Assert
        Assert-Equal -Expected @('issue', 'edit', '12', '--body-file', $file.Path) -Actual $call.Arguments `
            -Message "A body is a change, and is sent: $($case.Name)"
        Assert-Equal -Expected $case.Text -Actual $file.Text -Message "A body reaches gh exactly: $($case.Name)"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a body given as $null, which a text parameter cannot tell from ''
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Body $null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = Get-IssueTextFile -Call $call

    # Assert
    Assert-Equal -Expected @('issue', 'edit', '12', '--body-file', $file.Path) -Actual $call.Arguments `
        -Message 'A $null body is sent'
    Assert-Equal -Expected '' -Actual $file.Text -Message 'as an empty one, which clears the body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every value edit
$fake = New-FakeGitHubCli
try {
    # Act
    $edits = @{
        Milestone    = 'v2'
        Type         = 'Bug'
        Parent       = 5
        AddAssignee  = @('@me')
        AddProject   = @('Roadmap')
        AddSubIssue  = @(6, '#8')
        AddBlockedBy = @(1)
        AddBlocking  = @(3)
    }
    Set-GitHubIssue -Issue 12 @edits
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'issue', 'edit', '12', '--milestone=v2', '--type=Bug', '--parent', '5', '--add-assignee=@me'
        '--add-project=Roadmap', '--add-sub-issue', '6', '--add-sub-issue', '8', '--add-blocked-by', '1'
        '--add-blocking', '3'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments -Message 'Each edit becomes its gh flag, in declared order'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every removal
$fake = New-FakeGitHubCli
try {
    # Act
    $edits = @{
        RemoveMilestone = $true
        RemoveType      = $true
        RemoveParent    = $true
        RemoveAssignee  = @('bob')
        RemoveProject   = @('Old')
        RemoveSubIssue  = @(7)
        RemoveBlockedBy = @(2)
        RemoveBlocking  = @(4)
    }
    Set-GitHubIssue -Issue 12 @edits
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'issue', 'edit', '12', '--remove-milestone', '--remove-type', '--remove-parent', '--remove-assignee=bob'
        '--remove-project=Old', '--remove-sub-issue', '7', '--remove-blocked-by', '2', '--remove-blocking', '4'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Each removal becomes its gh flag, in declared order'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names gh would split at a comma or fail to read
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -AddLabel 'bug, urgent' -RemoveLabel 'say "hi"' -AddAssignee 'a"b' -RemoveProject 'Q1, Q2'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'issue', 'edit', '12', '--add-label="bug, urgent"', '--remove-label="say ""hi"""', '--add-assignee="a""b"'
        '--remove-project="Q1, Q2"'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Labels, assignees and projects go as CSV fields, so each stays one name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - related issues given as listed issues
$listed = [PSCustomObject]@{ Number = 5; Url = 'https://github.com/o/r/issues/5' }
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Parent $listed -AddSubIssue @($listed, @{ Number = 6 }) `
        -RemoveBlocking ([PSCustomObject]@{ Number = 7 })
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'issue', 'edit', '12', '--parent', 'https://github.com/o/r/issues/5'
        '--add-sub-issue', 'https://github.com/o/r/issues/5', '--add-sub-issue', '6', '--remove-blocking', '7'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'An issue object is read by its Url or Number, not by its text'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value and its removal together, which gh always refuses, and
# related issues that name no issue
$refused = @(
    @{
        Options = @{ Milestone = 'v1'; RemoveMilestone = $true }
        Pattern = '-Milestone and -RemoveMilestone cannot be used together: one sets the milestone and the other removes it. Give only one.'
        Message = 'A milestone and its removal are refused together'
    }
    @{
        Options = @{ Type = 'Bug'; RemoveType = $true }
        Pattern = '-Type and -RemoveType cannot be used together: one sets the type and the other removes it. Give only one.'
        Message = 'as are a type and its removal'
    }
    @{
        Options = @{ Parent = 5; RemoveParent = $true }
        Pattern = '-Parent and -RemoveParent cannot be used together: one sets the parent and the other removes it. Give only one.'
        Message = 'and a parent and its removal'
    }
    @{
        Options = @{ Title = ' ' }
        Pattern = '-Title is blank, and an issue needs a title.'
        Message = 'A blank -Title is refused, not dropped'
    }
    @{
        Options = @{ Title = ''; Body = 'x' }
        Pattern = '-Title is blank, and an issue needs a title.'
        Message = 'as is an empty one, even next to another change'
    }
    @{
        Options = @{ Milestone = '' }
        Pattern = '-Milestone is blank: give a milestone''s name, or leave it out. -RemoveMilestone takes the issue out of its milestone.'
        Message = 'A blank -Milestone points at -RemoveMilestone'
    }
    @{
        Options = @{ Type = ' ' }
        Pattern = '-Type is blank: give an issue type''s name, or leave it out. -RemoveType removes the issue''s type.'
        Message = 'and a blank -Type at -RemoveType'
    }
    @{
        Options = @{ Parent = @(1, 2) }
        Pattern = 'Give one issue at a time, not a list of 2; call once per issue.'
        Message = 'Several parents are refused, without advice to pipe them, which -Parent cannot take'
    }
    @{
        Options = @{ Parent = $null }
        Pattern = 'An issue was given, but it is $null.'
        Message = 'A -Parent given as $null is refused, not dropped'
    }
    @{
        Options = @{ AddSubIssue = @(6, $null) }
        Pattern = 'An issue was given, but it is $null.'
        Message = 'as is a $null among the sub-issues'
    }
    @{
        Options = @{ AddBlockedBy = 'https://github.com/o/r/pull/3' }
        Pattern = '*is a pull request, not an issue*'
        Message = 'A pull request is not an issue to be blocked by'
    }
)
$lists = [ordered]@{
    AddLabel       = '--add-label'
    RemoveLabel    = '--remove-label'
    AddAssignee    = '--add-assignee'
    RemoveAssignee = '--remove-assignee'
    AddProject     = '--add-project'
    RemoveProject  = '--remove-project'
}
foreach ($name in $lists.Keys) {
    $refused += @{
        Options = @{ $name = @('kept', ' ') }
        Pattern = "-$name has a blank element, which would send $($lists[$name])= with nothing after it." +
        " Give names, or leave -$name out."
        Message = "A blank element in -$name is refused, not sent as an empty name"
    }
}
$fake = New-FakeGitHubCli
try {
    foreach ($case in $refused) {
        $options = $case.Options

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Set-GitHubIssue -Issue 12 @options
        } -MessageLike $case.Pattern -Message $case.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pinning alone
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Pinned
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'With nothing to edit, only the pin call is made'
    Assert-Equal -Expected @('issue', 'pin', '12') -Actual $calls[0].Arguments -Message '-Pinned pins the issue'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - unpinning alongside an edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Title 'Unpinned' -Pinned:$false
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'An edit and a pin change are two gh calls'
    Assert-Equal -Expected @('issue', 'edit', '12', '--title=Unpinned') -Actual $calls[0].Arguments `
        -Message 'The edit goes first'
    Assert-Equal -Expected @('issue', 'unpin', '12') -Actual $calls[1].Arguments `
        -Message '-Pinned:$false unpins the issue'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the issue piped in as an object with only a Number
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Number = 9 } | Set-GitHubIssue -Title 'x'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'edit', '9', '--title=x') -Actual $call.Arguments `
        -Message 'The Number property binds from the pipeline as -Issue'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two issues piped in with one body
$fake = New-FakeGitHubCli
try {
    # Act
    @(1, 2) | Set-GitHubIssue -Body 'Same'
    $files = @(Get-FakeGitHubCall -Fixture $fake).ForEach({ Get-IssueTextFile -Call $_ })

    # Assert
    Assert-Equal -Expected @('Same', 'Same') -Actual @($files.Text) -Message 'Each piped issue gets the body'
    Assert-That -Condition ($files[0].Path -ne $files[1].Path) -Message 'in a file of its own'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing asked for
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue 12 -AddLabel @()
    } -MessageLike 'Say what to change - for example -Title, -Body, -AddLabel, or -Pinned.' `
        -Message 'A call that changes nothing is refused, not run as a silent no-op'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'

    # Act
    $thrown = try {
        Set-GitHubIssue -Issue 12 -AddLabel @()
    }
    catch {
        $_.Exception.Message
    }

    # Assert
    $expected = 'Say what to change - for example -Title, -Body, -AddLabel, or -Pinned.'
    Assert-Equal -Expected $expected -Actual $thrown -Message 'The message is a sentence, starting with a capital'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an edit that gh refuses, with a pin change after it
$fake = New-FakeGitHubCli -ErrorOutput @('could not add label: ''nope'' not found') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue 12 -AddLabel 'nope' -Pinned
    } -MessageLike '*Editing issue 12 failed*could not add label*' `
        -Message 'A refused edit throws with the message from gh'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and the pin change that followed it is not attempted'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refuses to pin or unpin an issue given by URL
$url = 'https://github.com/o/r/issues/5'
$fake = New-FakeGitHubCli -ErrorOutput @('pin limit reached') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue $url -Pinned
    } -MessageLike "Pinning issue $url failed: *pin limit reached*" `
        -Message 'A refused pin names the issue in a readable sentence'
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue $url -Pinned:$false
    } -MessageLike "Unpinning issue $url failed: *pin limit reached*" -Message 'and so does a refused unpin'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the edit goes through, the pin after it fails
$fake = New-FakeGitHubCli -Sequence @(@{ ExitCode = 0 }, @{ ErrorOutput = @('pin limit reached'); ExitCode = 1 })
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue 5 -AddLabel 'bug' -Pinned
    } -MessageLike 'Issue 5 was edited, but pinning it failed: Pinning issue 5 failed*pin limit reached*' `
        -Message 'A refused pin says the edit was kept'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the edit goes through, the unpin after it fails
$fake = New-FakeGitHubCli -Sequence @(@{ ExitCode = 0 }, @{ ErrorOutput = @('not pinned'); ExitCode = 1 })
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue 5 -AddLabel 'bug' -Pinned:$false
    } -MessageLike 'Issue 5 was edited, but unpinning it failed: Unpinning issue 5 failed*not pinned*' `
        -Message 'and so does a refused unpin'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with an edit and a pin
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        $edit = @{
            Title       = 'New title'
            Body        = 'Secret text'
            AddLabel    = @('bug')
            AddSubIssue = @(4)
            Pinned      = $true
            Repository  = 'o/r'
        }
        Set-GitHubIssue -Issue 12 @edit -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Edit issue" on target "o/r issue #12".'
        'What if: Performing the operation "Pin issue" on target "o/r issue #12".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names each change on its own, never the body'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and changes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with only an unpin, and with only a body
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubIssue -Issue 12 -Pinned:$false -WhatIf
        Set-GitHubIssue -Issue 13 -Body '' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Unpin issue" on target "issue #12".'
        'What if: Performing the operation "Edit issue" on target "issue #13".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names only the change asked for'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and changes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with no change, and with a value and its removal
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue 12 -WhatIf
    } -MessageLike 'Say what to change - for example -Title, -Body, -AddLabel, or -Pinned.' `
        -Message '-WhatIf is no change to make'
    Assert-Throws -ScriptBlock {
        Set-GitHubIssue -Issue 12 -Milestone 'v1' -RemoveMilestone -WhatIf
    } -MessageLike '-Milestone and -RemoveMilestone cannot be used together*' `
        -Message 'and -WhatIf still refuses a value with its removal'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two issues piped under -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @('1', '2') | Set-GitHubIssue -AddLabel 'bug' -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Edit issue" on target "o/r issue #1".'
        'What if: Performing the operation "Edit issue" on target "o/r issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped issue'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and edits neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
