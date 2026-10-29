#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    Save-GitStash -Message 'wip' -RepoPath $repo

    # Act
    $restored = Restore-GitStash -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $restored.Conflict -Message 'A clean restore reports no conflict'
    Assert-Equal -Expected @('Conflict', 'Paths') -Actual @($restored.PSObject.Properties.Name) `
        -Message 'A clean result has Paths too, so reading it never throws under strict mode'
    Assert-Equal -Expected 0 -Actual $restored.Paths.Count -Message 'and it is empty'
    Assert-Equal -Expected 'changed' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'The change comes back'
    Assert-Equal -Expected 0 -Actual @(Get-GitStash -RepoPath $repo).Count `
        -Message 'Restoring removes the stash from the list'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two stashes, restoring a specific index
    git -C $repo checkout -q -- a.txt 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'first' -NoNewline
    Save-GitStash -Message 'first stash' -RepoPath $repo
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'second' -NoNewline
    Save-GitStash -Message 'second stash' -RepoPath $repo

    # Act - index 1 is the OLDER of the two (0 is most recent)
    Restore-GitStash -Index 1 -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'first' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'The chosen stash index is restored'
    Assert-Equal -Expected 1 -Actual @(Get-GitStash -RepoPath $repo).Count -Message 'Only the restored stash is removed'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - an index that cannot name a stash
    Assert-Throws -ScriptBlock {
        Restore-GitStash -Index -1 -RepoPath $repo
    } -MessageLike '*Index*' -Message 'A negative -Index is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a stash of one change, then a committed change to the same line
    git -C $repo stash clear 2>&1 | Out-Null
    git -C $repo checkout -q -- a.txt 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'stashed' -NoNewline
    $null = Save-GitStash -RepoPath $repo
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'committed' -NoNewline
    git -C $repo commit --quiet -am 'conflicting change' 2>&1 | Out-Null

    # Act
    $conflicted = Restore-GitStash -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $conflicted.Conflict `
        -Message 'A stash that conflicts reports a conflict instead of throwing'
    Assert-Equal -Expected @('a.txt') -Actual $conflicted.Paths -Message 'with the conflicted path'
    Assert-Equal -Expected 1 -Actual @(Get-GitStash -RepoPath $repo).Count -Message 'and the stash is kept'
    git -C $repo reset -q --hard 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a stash that does not exist
    Assert-Throws -ScriptBlock { Restore-GitStash -Index 5 -RepoPath $repo } `
        -MessageLike '*Restoring the stash failed*' -Message 'A stash that does not exist throws'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a stashed edit to b.txt, then a merge that stops on a conflict in
# a.txt, which the stash has nothing to do with
$repo = New-GitTestPathRepo -Path 'b.txt'
try {
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'stashed' -NoNewline
    $null = Save-GitStash -RepoPath $repo
    git -C $repo checkout -q -b side 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from side' -NoNewline
    git -C $repo commit --quiet -am 'side' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from main' -NoNewline
    git -C $repo commit --quiet -am 'main' 2>&1 | Out-Null
    git -C $repo merge --no-edit side 2>&1 | Out-Null

    # Act / Assert
    Assert-Throws -ScriptBlock { Restore-GitStash -RepoPath $repo } `
        -MessageLike '*Restoring the stash failed: the index already has unresolved conflicts (a.txt)*the stash is kept.*' `
        -Message 'An earlier conflict is not reported as the stash''s own'
    Assert-Equal -Expected 1 -Actual @(Get-GitStash -RepoPath $repo).Count `
        -Message 'and the stash, never applied, is still listed'
    Assert-Equal -Expected 'base' -Actual (Get-Content -LiteralPath (Join-Path $repo 'b.txt') -Raw) `
        -Message 'with its change not applied'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act
    $thrown = try {
        Restore-GitStash -RepoPath $plain
        '(did not throw)'
    }
    catch {
        $_.Exception.Message
    }

    # Assert
    Assert-That -Condition ($thrown -like '*not a git repository*') -Message 'A folder that is no repository says so'
    Assert-That -Condition ($thrown -notlike '*usage:*') -Message 'without a page of usage text'
}
finally {
    Remove-GitTestRepo -Path $plain
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a stash, and an uncommitted change to the same file
$repo = New-GitTestRepo
try {
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'stashed' -NoNewline
    git -C $repo stash push --quiet 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'uncommitted' -NoNewline

    # Act / Assert
    Assert-Throws -ScriptBlock { Restore-GitStash -RepoPath $repo } `
        -MessageLike '*Restoring the stash failed (exit 1):*overwritten*' `
        -Message 'A stash that would overwrite uncommitted changes throws, quoting git'
    Assert-Equal -Expected 1 -Actual @(Get-GitStash -RepoPath $repo).Count -Message 'and the stash is kept'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
