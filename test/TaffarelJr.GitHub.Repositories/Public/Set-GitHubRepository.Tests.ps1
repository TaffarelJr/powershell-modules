#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - plain value settings
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Description 'd' -Homepage 'https://h' -DefaultBranch 'main' `
        -AddTopic @('ci', 'gh') `
        -RemoveTopic @('old')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'repo', 'edit', 'o/r', '--description=d', '--homepage=https://h', '--default-branch=main', '--add-topic=ci',
            '--add-topic=gh', '--remove-topic=old'
        ) `
        -Actual $call.Arguments `
        -Message 'Each value setting becomes its gh flag, one --add-topic/--remove-topic per topic'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a description and home page cleared, and a description that is only --
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Description '' -Homepage ''
    Set-GitHubRepository -Repository 'o/r' -Description '--'
    Set-GitHubRepository -Repository 'o/r' -DefaultBranch '-x' -AddTopic '-y'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'edit', 'o/r', '--description=', '--homepage=') -Actual $calls[0].Arguments `
        -Message 'An empty description or home page is sent, which clears it'
    Assert-Equal -Expected @('repo', 'edit', 'o/r', '--description=--') -Actual $calls[1].Arguments `
        -Message 'A free-text value travels joined to its flag, so even -- stays a value'
    Assert-Equal -Expected @('repo', 'edit', 'o/r', '--default-branch=-x', '--add-topic=-y') `
        -Actual $calls[2].Arguments `
        -Message 'as do a default branch and a topic'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a default squash-merge message, alone and beside an explicit squash-merge toggle
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -SquashMergeCommitMessage 'PR-Title'
    Set-GitHubRepository -Repository 'o/r' -SquashMergeCommitMessage 'default' -EnableSquashMerge
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('repo', 'edit', 'o/r', '--squash-merge-commit-message', 'pr-title', '--enable-squash-merge=true') `
        -Actual $calls[0].Arguments `
        -Message 'The message is lower-cased for gh''s exact check, and squash-merging is allowed with it, as gh requires'
    Assert-Equal `
        -Expected @('repo', 'edit', 'o/r', '--squash-merge-commit-message', 'default', '--enable-squash-merge=true') `
        -Actual $calls[1].Arguments `
        -Message 'An explicit -EnableSquashMerge is sent once, not twice'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a toggle on, a toggle off, and the rest left alone
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -EnableWiki:$false -DeleteBranchOnMerge -Template
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('repo', 'edit', '--enable-wiki=false', '--delete-branch-on-merge=true', '--template=true') `
        -Actual $call.Arguments `
        -Message 'A toggle given as $false turns off, one given turns on, and an omitted one is not mentioned; ordinary edits may use the current directory''s repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every remaining toggle
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -EnableIssues -EnableProjects -EnableDiscussions -EnableMergeCommit -EnableSquashMerge `
        -EnableRebaseMerge `
        -EnableAutoMerge `
        -EnableAdvancedSecurity `
        -EnableSecretScanning `
        -EnableSecretScanningPushProtection `
        -AllowForking `
        -AllowUpdateBranch
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'repo', 'edit', '--enable-issues=true', '--enable-projects=true', '--enable-discussions=true',
            '--enable-merge-commit=true', '--enable-squash-merge=true', '--enable-rebase-merge=true',
            '--enable-auto-merge=true', '--enable-advanced-security=true', '--enable-secret-scanning=true',
            '--enable-secret-scanning-push-protection=true', '--allow-forking=true', '--allow-update-branch=true'
        ) `
        -Actual $call.Arguments `
        -Message 'Every toggle maps to its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a visibility change, in mixed case
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Visibility 'Private'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('repo', 'edit', 'o/r', '--visibility', 'private', '--accept-visibility-change-consequences') `
        -Actual $call.Arguments `
        -Message 'The visibility is lower-cased and carries the acknowledgement gh requires'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - archiving alone, nothing to edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Archived
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'With nothing to edit, only the archive call is made'
    Assert-Equal -Expected @('repo', 'archive', 'o/r', '--yes') -Actual $calls[0].Arguments `
        -Message '-Archived archives without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - unarchiving alongside an edit, which a read-only repository would refuse
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Description 'back' -Archived:$false
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'An edit and an archive change are two gh calls'
    Assert-Equal -Expected @('repo', 'unarchive', 'o/r', '--yes') -Actual $calls[0].Arguments `
        -Message 'Unarchiving goes first, so the edit does not meet a read-only repository'
    Assert-Equal -Expected @('repo', 'edit', 'o/r', '--description=back') -Actual $calls[1].Arguments `
        -Message 'and the edit second'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repository objects piped in as a listing returns them, edited then archived
$fake = New-FakeGitHubCli
try {
    # Act
    @(
        [PSCustomObject]@{ NameWithOwner = 'o/a'; Name = 'a' },
        [PSCustomObject]@{ NameWithOwner = 'o/b'; Url = 'https://github.com/o/b' }
    ) | Set-GitHubRepository `
        -DeleteBranchOnMerge `
        -Archived
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 4 -Actual $calls.Count `
        -Message 'Each piped repository is edited and then archived, in two calls of its own'
    Assert-Equal -Expected @('repo', 'edit', 'o/a', '--delete-branch-on-merge=true') -Actual $calls[0].Arguments `
        -Message 'An object is read by its NameWithOwner, not its text'
    Assert-Equal -Expected @('repo', 'archive', 'o/a', '--yes') -Actual $calls[1].Arguments `
        -Message 'and archived after the edit, which a piped object names well enough'
    Assert-Equal -Expected @('repo', 'edit', 'https://github.com/o/b', '--delete-branch-on-merge=true') `
        -Actual $calls[2].Arguments `
        -Message 'An object with a Url is read by it first'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing at all to change, and a squash message squash-merging is forbidden for
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r'
    } -MessageLike 'Say what to change - for example -Description, -DefaultBranch, -EnableWiki, or -Archived.' `
        -Message 'A call that changes nothing is refused, not run as a silent no-op'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -AddTopic @()
    } -MessageLike '-AddTopic was given no topics, so it would change nothing. Give a value, or leave -AddTopic off.' `
        -Message 'An empty list of topics is refused, as a filter that matched nothing gives'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -Description ' '
    } -MessageLike '-Description is blank: give the text, or an empty string to clear it.' `
        -Message 'A description of only spaces is refused, while an empty one clears'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -Homepage ' '
    } -MessageLike '-Homepage is blank: give the text, or an empty string to clear it.' `
        -Message 'as is such a home page'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -DefaultBranch ''
    } -MessageLike '-DefaultBranch is blank, and a repository needs a default branch.' `
        -Message 'A blank default branch is refused, saying so rather than that nothing was given'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -AddTopic 'ci', ' '
    } -MessageLike '-AddTopic has a blank element, which would send --add-topic= with nothing after it. Give topics, or leave -AddTopic off.' `
        -Message 'A blank topic to add is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -RemoveTopic ''
    } -MessageLike '-RemoveTopic has a blank element, which would send --remove-topic= with nothing after it. Give topics, or leave -RemoveTopic off.' `
        -Message 'as is one to remove'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -SquashMergeCommitMessage 'pr-title' -EnableSquashMerge:$false
    } -MessageLike '-SquashMergeCommitMessage and -EnableSquashMerge:$false cannot be used together: the message needs squash-merging allowed, which -EnableSquashMerge:$false forbids. Give only one.' `
        -Message 'A squash message beside forbidding squash-merging is refused, as gh would refuse it'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called at all'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository given as $null, as a filter that matched nothing gives
$fake = New-FakeGitHubCli
try {
    # Act
    $missing = @() | Where-Object { $_ }

    # Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository $missing -Archived
    } -MessageLike "-Repository was given, but it is `$null - leave it out to use the current directory's repository." `
        -Message 'A $null repository throws, rather than archiving the current directory''s'
    Assert-Throws -ScriptBlock {
        $null | Set-GitHubRepository -Description 'd'
    } -MessageLike '-Repository was given, but it is $null*' -Message 'as does a piped $null, for any change'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - archiving or changing visibility with no repository named
$fake = New-FakeGitHubCli
try {
    # Act
    $unnamed = '-Visibility and -Archived change a repository for good, so name the repository with -Repository or pipe it in - the current directory''s is not assumed.'

    # Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Archived
    } -MessageLike $unnamed -Message '-Archived needs the repository named'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Archived:$false -Description 'd'
    } -MessageLike $unnamed -Message 'as does -Archived:$false'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Visibility public
    } -MessageLike $unnamed -Message 'and -Visibility'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh failing each kind of change
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 403: Forbidden') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -Description 'd'
    } -MessageLike 'Editing repository o/r failed*Forbidden*' -Message 'A failed edit names the repository'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Description 'd'
    } -MessageLike 'Editing the current directory''s repository failed*Forbidden*' `
        -Message 'or says it was the current directory''s'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -Archived
    } -MessageLike 'Archiving repository o/r failed*Forbidden*' -Message 'A failed archive names the repository'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -Archived:$false
    } -MessageLike 'Unarchiving repository o/r failed*Forbidden*' -Message 'as does a failed unarchive'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the unarchive goes through, the edit after it fails
$fake = New-FakeGitHubCli -Sequence @(@{ ExitCode = 0 }, @{ ErrorOutput = @('HTTP 403: Forbidden'); ExitCode = 1 })
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -Description 'd' -Archived:$false
    } -MessageLike 'Repository o/r was unarchived, but editing it failed: Editing repository o/r failed*Forbidden*' `
        -Message 'A failed edit says the repository was left unarchived'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the edit goes through, the archive after it fails
$fake = New-FakeGitHubCli -Sequence @(@{ ExitCode = 0 }, @{ ErrorOutput = @('HTTP 403: Forbidden'); ExitCode = 1 })
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -Description 'd' -Archived
    } -MessageLike 'Repository o/r was edited, but archiving it failed: Archiving repository o/r failed*Forbidden*' `
        -Message 'A failed archive says the edit was kept'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside an unarchive, an edit, and an archive, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(
        Set-GitHubRepository -Repository 'o/r' -Description 'd' -EnableWiki -Archived:$false -WhatIf
        Set-GitHubRepository -Repository 'o/r' -Visibility 'private' -Archived -WhatIf
        Set-GitHubRepository -DeleteBranchOnMerge -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls `
        -Message 'With -WhatIf gh is not called, so nothing is unarchived, edited, or archived'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Set-GitHubRepository -Repository 'o/r' -Description 'd' -EnableWiki -Archived -WhatIf:$false -Confirm:$false
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message '-WhatIf:$false and -Confirm:$false make both changes'
    Assert-Equal -Expected @('repo', 'edit', 'o/r', '--description=d', '--enable-wiki=true') -Actual $calls[0].Arguments `
        -Message 'the edit as before, neither one reaching gh as a flag'
    Assert-Equal -Expected @('repo', 'archive', 'o/r', '--yes') -Actual $calls[1].Arguments -Message 'and the archive'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two repositories piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @('o/a', 'o/b' | Set-GitHubRepository -DeleteBranchOnMerge -Archived -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped repository is edited or archived'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with nothing to change, and with -Archived and no repository named
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Repository 'o/r' -WhatIf
    } -MessageLike 'Say what to change - for example -Description, -DefaultBranch, -EnableWiki, or -Archived.' `
        -Message '-WhatIf still refuses a call that changes nothing'
    Assert-Throws -ScriptBlock {
        Set-GitHubRepository -Archived -WhatIf
    } -MessageLike '-Visibility and -Archived change a repository for good, so name the repository*' `
        -Message 'and -Archived with no repository named'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for each kind of change, with a credential in -Repository's URL
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubRepository -Repository 'https://user:SENTINEL@github.com/o/r' -Description 'd' -Archived:$false `
            -WhatIf
        Set-GitHubRepository -Repository 'o/r' -Visibility 'private' -Archived -WhatIf
        Set-GitHubRepository -DeleteBranchOnMerge -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Unarchive and edit repository" on target "o/r".'
        'What if: Performing the operation "Edit and archive repository" on target "o/r".'
        'What if: Performing the operation "Edit repository" on target "the current directory''s repository".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names each change and the repository, without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two repositories piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock { 'o/a', 'o/b' | Set-GitHubRepository -Archived -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Archive repository" on target "o/a".'
        'What if: Performing the operation "Archive repository" on target "o/b".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped repository gets its own line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
