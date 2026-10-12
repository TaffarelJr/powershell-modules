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
# Arrange - a title and a multi-line body
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/pull/13')
try {
    # Act
    $url = New-GitHubPullRequest -Title 'Sync template' -Body "Line 1`n`nLine 3`n" -Base 'main' -Head 'template-sync' `
        -Label @('template sync') `
        -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'pr', 'create', '--title=Sync template', '--body-file', $file, '--base=main', '--head=template-sync',
            '--label=template sync', '--repo', 'o/r'
        ) `
        -Actual $call.Arguments `
        -Message 'The body is read from a file; the rest become their gh flags'
    Assert-Equal -Expected "Line 1`n`nLine 3`n" -Actual $call.Files[$file] `
        -Message 'which holds the body exactly, blank lines included'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped'
    Assert-Equal -Expected 'https://github.com/o/r/pull/13' -Actual $url `
        -Message 'The new pull request''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a title that is exactly the end-of-options marker
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/pull/15')
try {
    # Act
    New-GitHubPullRequest -Title '--' -Fill -Repository 'o/r' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'create', '--title=--', '--fill', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'A title goes as --title=value, so a title of -- cannot end gh''s options'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other option, filled from the first commit
$fake = New-FakeGitHubCli -Output @('Warning: 1 uncommitted change', 'https://github.com/o/r/pull/14')
try {
    # Act
    $url = New-GitHubPullRequest -Draft -Assignee @('@me', 'bob') -Reviewer @('org/team') -Milestone 'v1' `
        -Project @('Roadmap') `
        -FillFirst `
        -NoMaintainerEdit
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'pr', 'create', '--draft', '--assignee=@me', '--assignee=bob', '--reviewer=org/team', '--milestone=v1',
            '--project=Roadmap', '--fill-first', '--no-maintainer-edit'
        ) `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, one per list element'
    Assert-Equal -Expected 0 -Actual $call.Files.Count -Message 'No file is passed without -Body'
    Assert-Equal -Expected 'https://github.com/o/r/pull/14' -Actual $url `
        -Message 'The URL is picked out from among other output lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names holding a comma or a quote
$fake = New-FakeGitHubCli -Output @('https://x')
try {
    # Act
    New-GitHubPullRequest -Fill -Label 'a,b' -Assignee 'me' -Reviewer 'say "hi"' -Project 'Q1, Q2' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'pr', 'create', '--label="a,b"', '--assignee=me', '--reviewer="say ""hi"""', '--project="Q1, Q2"', '--fill'
        ) `
        -Actual $call.Arguments `
        -Message 'Each name goes as one CSV field, so gh does not split it at a comma'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the other two ways to fill the details in
$fake = New-FakeGitHubCli -Output @('https://x')
try {
    # Act
    New-GitHubPullRequest -Fill | Out-Null
    New-GitHubPullRequest -FillVerbose -Title 'Own title' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('pr', 'create', '--fill') -Actual $calls[0].Arguments -Message '-Fill becomes --fill'
    Assert-Equal -Expected @('pr', 'create', '--title=Own title', '--fill-verbose') -Actual $calls[1].Arguments `
        -Message '-FillVerbose becomes --fill-verbose, and a title may go with it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two ways to fill the details in at once, which gh refuses
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubPullRequest -Fill -FillFirst
    } -MessageLike '*Parameter set cannot be resolved*' -Message '-Fill and -FillFirst are refused together'
    Assert-Throws -ScriptBlock {
        New-GitHubPullRequest -Fill -FillVerbose
    } -MessageLike '*Parameter set cannot be resolved*' -Message 'and so are -Fill and -FillVerbose'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a dry run, whose output is gh's account of what it would create
$fake = New-FakeGitHubCli `
    -Output @('Would have created a Pull Request with:', "title:`tSync", "draft:`tfalse", "base:`tmain")
try {
    # Act
    $out = @(New-GitHubPullRequest -Title 'Sync' -Body 'text' -DryRun)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = @($call.Files.Keys)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'create', '--title=Sync', '--body-file', $file, '--dry-run') `
        -Actual $call.Arguments `
        -Message '-DryRun becomes --dry-run'
    Assert-Equal `
        -Expected @('Would have created a Pull Request with:', "title:`tSync", "draft:`tfalse", "base:`tmain") `
        -Actual $out `
        -Message 'The lines gh prints are returned, since there is no URL to pick out'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refuses to ask for the details
$fake = New-FakeGitHubCli `
    -ErrorOutput @('must provide `--title` and `--body` (or `--fill` or `fill-first` or `--fillverbose`) when not running interactively') `
    -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubPullRequest -Title 'Only a title'
    } -MessageLike '*Creating the pull request failed*must provide*when not running interactively*' `
        -Message 'A call with too little to go on throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - blank values, which would otherwise be dropped or sent as nothing
$fake = New-FakeGitHubCli
try {
    $blanks = [ordered]@{
        Title     = '-Title is blank: give a title, or leave it out.'
        Base      = '-Base is blank: give the base branch, or leave it out.'
        Head      = '-Head is blank: give the head branch, or leave it out.'
        Milestone = '-Milestone is blank: give a milestone name, or leave it out.'
    }
    foreach ($name in $blanks.Keys) {
        $blank = @{ $name = ' ' }

        # Act / Assert
        Assert-Throws -ScriptBlock {
            New-GitHubPullRequest -Fill @blank
        } -MessageLike $blanks[$name] -Message "A blank -$name is refused, not dropped"
    }

    Assert-Throws -ScriptBlock {
        New-GitHubPullRequest -Fill -Project 'Roadmap', ''
    } -MessageLike '-Project has a blank element, which would send --project= with nothing after it. Give names, or leave -Project out.' `
        -Message 'and so is a blank name in a list'
    Assert-Throws -ScriptBlock {
        New-GitHubPullRequest 'Title'
    } -MessageLike '*positional parameter cannot be found*' -Message 'No parameter is taken by position'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a body, branches, and lists
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/pull/13')
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        New-GitHubPullRequest -Title 'Sync template' -Body 'Private text' -Base 'main' -Head 'template-sync' `
            -Label @('a', 'b') `
            -Reviewer 'org/team' `
            -Draft `
            -Repository 'o/r' `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Create draft pull request ''Sync template'' from template-sync' +
    ' into main" on target "o/r".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the repository, the draft, its title, and the branches, never the body'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned, not even a URL'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a dry run in the current directory's repository
$fake = New-FakeGitHubCli -Output @('Would have created a Pull Request with:')
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        New-GitHubPullRequest -Fill -DryRun -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Dry-run creating a pull request, filled in from the commits,' +
    ' which may push the head branch" on target "the current directory''s repository".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message 'A dry run is guarded too, since gh may push the branch for it'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'nor anything returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a credential in a repository URL, a title, and a fill
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        New-GitHubPullRequest -Title 'Sync' -FillVerbose -Repository 'https://user:SENTINEL@github.com/o/r' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Create pull request ''Sync'', filled in from every commit"' +
    ' on target "o/r".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the repository without the credential its URL carried'
    Assert-Equal -Expected 0 -Actual @($result.Messages -match 'SENTINEL').Count -Message 'which no line holds'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank name in a list
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubPullRequest -Fill -Label @('bug', ' ') -WhatIf
    } -MessageLike '-Label has a blank element, which would send --label= with nothing after it.*' `
        -Message 'A blank label is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
