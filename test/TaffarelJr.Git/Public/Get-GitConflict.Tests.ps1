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
    # Arrange / Act / Assert - no conflicts outside a merge
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count -Message 'A clean repo has no conflicts'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two branches that conflict on the same file
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null

    # Act
    $conflicts = @(Get-GitConflict -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $conflicts.Count -Message 'The conflicted path is reported'
    Assert-Equal -Expected 'a.txt' -Actual $conflicts[0] -Message 'The correct path is reported'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a conflict on a file whose name git would quote and escape
    git -C $repo merge --abort 2>&1 | Out-Null
    $accented = "caf$([char]0xE9) au lait.txt"
    git -C $repo checkout -q -b accent-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo $accented) -Value 'a' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add on accent-a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo $accented) -Value 'main' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit accent-a 2>&1 | Out-Null

    # Act
    $escaped = @(Get-GitConflict -RepoPath $repo)

    # Assert
    Assert-Equal -Expected $accented -Actual $escaped[0] `
        -Message 'A path with a space and an accent comes back as the name on disk'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a conflict in a root file, read from a subfolder
$repo = New-GitTestPathRepo -Path 'sub/keep.txt'
try {
    git -C $repo checkout -q -b side 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from side' -NoNewline
    git -C $repo commit --quiet -am 'side' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from main' -NoNewline
    git -C $repo commit --quiet -am 'main' 2>&1 | Out-Null
    git -C $repo merge --no-edit side 2>&1 | Out-Null

    # Act
    $fromSub = @(Get-GitConflict -RepoPath (Join-Path $repo 'sub'))

    # Assert
    Assert-Equal -Expected @('a.txt') -Actual $fromSub `
        -Message 'Each conflicted path comes back once, relative to the root, from any folder'
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
        Get-GitConflict -RepoPath $plain
        '(did not throw)'
    }
    catch {
        $_.Exception.Message
    }

    # Assert
    Assert-That -Condition ($thrown -like '*Reading conflicted paths failed*not a git repository*') `
        -Message 'A folder that is no repository says so'
    Assert-That -Condition ($thrown -notlike '*usage:*') -Message 'without a page of usage text'
}
finally {
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
