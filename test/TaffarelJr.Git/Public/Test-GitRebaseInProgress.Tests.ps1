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
    # Arrange / Act / Assert - nothing in progress normally
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message 'A plain repo has no rebase in progress'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rebase paused on a conflict
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'feature' -NoNewline
    git -C $repo commit --quiet -am 'feature change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main' -NoNewline
    git -C $repo commit --quiet -am 'main change' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null
    git -C $repo rebase main 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $true -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message 'A paused rebase is detected'

    #───────────────────────────────────────────────────────────────────────────
    # Act - after aborting
    git -C $repo rebase --abort 2>&1 | Out-Null

    # Assert
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message 'An aborted rebase is no longer in progress'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a 'git am' paused on a patch that does not apply, which leaves the
    # same rebase-apply folder an older rebase does
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'patched' -NoNewline
    git -C $repo commit --quiet -am 'to export' 2>&1 | Out-Null
    $patches = Join-Path ([System.IO.Path]::GetTempPath()) "patches-$([Guid]::NewGuid())"
    git -C $repo format-patch -1 -o $patches 2>&1 | Out-Null
    git -C $repo reset -q --hard HEAD~1 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'conflicting' -NoNewline
    git -C $repo commit --quiet -am 'conflicting' 2>&1 | Out-Null
    git -C $repo am (Get-ChildItem -LiteralPath $patches).FullName 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $true `
        -Actual (Test-Path -LiteralPath (Join-Path $repo '.git' 'rebase-apply') -PathType Container) `
        -Message 'Precondition: git am left a rebase-apply folder'
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message 'A paused git am is not a rebase'

    # Act
    git -C $repo am --abort 2>&1 | Out-Null
    Remove-Item -LiteralPath $patches -Recurse -Force -ErrorAction SilentlyContinue

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rebase that uses the older apply machinery
    git -C $repo checkout -q -b applying 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'applying' -NoNewline
    git -C $repo commit --quiet -am 'applying change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main-again' -NoNewline
    git -C $repo commit --quiet -am 'main again' 2>&1 | Out-Null
    git -C $repo checkout -q applying 2>&1 | Out-Null
    git -C $repo rebase --apply main 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $true -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message 'A rebase using the apply backend is a rebase'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $plain) `
        -Message 'A folder that is no repository has no rebase under way'
}
finally {
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
