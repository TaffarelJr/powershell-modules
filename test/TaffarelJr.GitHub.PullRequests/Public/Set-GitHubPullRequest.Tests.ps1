#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a new title and body, and a label swap
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -PullRequest 12 -Title 'Renamed' -Body "New`r`nbody`n" -AddLabel @('needs fix') `
        -RemoveLabel @('ready') `
        -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'pr', 'edit', '12', '--body-file', $file, '--title=Renamed', '--add-label=needs fix',
            '--remove-label=ready', '--repo', 'o/r'
        ) `
        -Actual $call.Arguments `
        -Message 'The body is read from a file; the rest become their gh flags'
    Assert-Equal -Expected "New`r`nbody`n" -Actual $call.Files[$file] -Message 'which holds the body exactly'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every remaining edit, on the current branch's pull request of
# another repository, which gh looks for even with --repo
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -Base 'develop' -Milestone 'v2' -AddAssignee @('@me') -RemoveAssignee @('bob') `
        -AddReviewer @('org/team', 'ann') `
        -RemoveReviewer @('cat') `
        -AddProject @('Roadmap') `
        -RemoveProject @('Old') `
        -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @(
            'pr', 'edit', '--base=develop', '--milestone=v2', '--add-assignee=@me', '--remove-assignee=bob',
            '--add-reviewer=org/team', '--add-reviewer=ann', '--remove-reviewer=cat', '--add-project=Roadmap',
            '--remove-project=Old', '--repo', 'o/r'
        ) -Actual $call.Arguments -Message 'Each edit becomes its gh flag, one per list element'
    Assert-Equal -Expected 0 -Actual $call.Files.Count -Message 'No file is passed without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names holding a comma, and the milestone taken away
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -PullRequest 4 -AddLabel 'a,b' -RemoveReviewer 'x,y' -RemoveMilestone
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'edit', '4', '--remove-milestone', '--add-label="a,b"', '--remove-reviewer="x,y"') `
        -Actual $call.Arguments `
        -Message 'Each name goes as one CSV field, so gh does not split it at a comma'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a milestone and its removal together, which gh refuses
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 4 -Milestone 'v2' -RemoveMilestone
    } -MessageLike '-Milestone and -RemoveMilestone cannot be used together: one sets the milestone and the other removes it. Give only one.' `
        -Message '-Milestone and -RemoveMilestone are refused together, with a sentence naming the pair'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - marking ready alone
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -PullRequest 12 -Ready
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'With nothing to edit, only the ready call is made'
    Assert-Equal -Expected @('pr', 'ready', '12') -Actual $calls[0].Arguments `
        -Message '-Ready marks the pull request ready for review'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - back to a draft, alongside an edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -Title 'WIP' -Ready:$false
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'An edit and a draft-state change are two gh calls'
    Assert-Equal -Expected @('pr', 'edit', '--title=WIP') -Actual $calls[0].Arguments -Message 'The edit goes first'
    Assert-Equal -Expected @('pr', 'ready', '--undo') -Actual $calls[1].Arguments `
        -Message '-Ready:$false converts the pull request to a draft'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the edit goes through, the draft-state change fails
$fake = New-FakeGitHubCli -Sequence @(@{ ExitCode = 0 }, @{ ErrorOutput = @('pull request is closed'); ExitCode = 1 })
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -Title 'Done' -Ready
    } -MessageLike "Pull request 12 was edited, but changing its draft state failed: Changing the draft state of pull request 12 failed*pull request is closed*" `
        -Message 'A failed second step says the edit was kept'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the draft-state change alone fails
$fake = New-FakeGitHubCli -ErrorOutput @('pull request is closed') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -Ready
    } -MessageLike 'Changing the draft state of pull request 12 failed*pull request is closed*' `
        -Message 'With no edit before it, the failure is gh''s alone'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the edit fails
$fake = New-FakeGitHubCli -ErrorOutput @('GraphQL: Could not resolve') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -Title 'x' -Ready
    } -MessageLike 'Editing pull request 12 failed*Could not resolve*' `
        -Message 'A failed edit throws before the draft state is touched'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'so gh is called once'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing to change
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -AddLabel @()
    } -MessageLike 'Say what to change - for example -Title, -Body, -AddLabel, or -Ready.' `
        -Message 'A call that changes nothing is refused, not run as a silent no-op'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called at all'

    # Act
    $message = try {
        Set-GitHubPullRequest -PullRequest 12
    }
    catch {
        $_.Exception.Message
    }

    # Assert
    Assert-Equal -Expected 'Say what to change - for example -Title, -Body, -AddLabel, or -Ready.' -Actual $message `
        -Message 'The sentence starts with a capital, which -MessageLike alone cannot tell'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - blank values, which would otherwise be dropped or sent as nothing
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -Title ' ' -AddLabel 'x'
    } -MessageLike '-Title is blank, and a pull request needs a title.' -Message 'A blank title is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -Base ''
    } -MessageLike '-Base is blank, and a pull request needs a base branch.' -Message 'and so is a blank base'
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -Milestone ''
    } -MessageLike '-Milestone is blank: use -RemoveMilestone to clear it.' `
        -Message 'and a blank milestone points at -RemoveMilestone'
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 12 -AddReviewer 'ann', ''
    } -MessageLike '-AddReviewer has a blank element, which would send --add-reviewer= with nothing after it. Give names, or leave -AddReviewer out.' `
        -Message 'and so is a blank name in a list'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty body, and a label that is exactly the end-of-options marker
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -PullRequest 12 -Body '' -AddLabel '--'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'edit', '12', '--body-file', $file, '--add-label=--') -Actual $call.Arguments `
        -Message 'A list name goes as --flag=value, so -- cannot end gh''s options'
    Assert-Equal -Expected '' -Actual $call.Files[$file] -Message 'An empty body clears it, through an empty file'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pull requests piped in, moved to a milestone
$fake = New-FakeGitHubCli
try {
    # Act
    @(3, 4) | Set-GitHubPullRequest -Milestone 'v2' -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('pr', 'edit', '3', '--milestone=v2', '--repo', 'o/r') -Actual $calls[0].Arguments `
        -Message 'A piped pull request binds along with -Milestone'
    Assert-Equal -Expected @('pr', 'edit', '4', '--milestone=v2', '--repo', 'o/r') -Actual $calls[1].Arguments `
        -Message 'one call per pull request'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with an edit and -Ready, two changes
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 4 -Title 'New title' -Body 'Private text' -AddLabel 'bug' -Ready `
            -Repository 'o/r' `
            -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Edit pull request" on target "o/r pull request #4".'
        'What if: Performing the operation "Mark pull request ready for review" on target "o/r pull request #4".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each of the two changes is named on its own, never the body'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with only -Ready:$false, and an edit of the current branch's pull request
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 4 -Ready:$false -WhatIf
        Set-GitHubPullRequest -RemoveMilestone -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Convert pull request to a draft" on target "pull request #4".'
        'What if: Performing the operation "Edit pull request" on target "the current branch''s pull request in o/r".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each call names only the change it asks for'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two pull requests piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        @(1, 2) | Set-GitHubPullRequest -AddReviewer 'org/team' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Edit pull request" on target "pull request #1".'
        'What if: Performing the operation "Edit pull request" on target "pull request #2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped pull request is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is edited'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf and nothing to change
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubPullRequest -PullRequest 4 -WhatIf
    } -MessageLike 'Say what to change - for example -Title, -Body, -AddLabel, or -Ready.' `
        -Message '-WhatIf is not taken for a change to make'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
