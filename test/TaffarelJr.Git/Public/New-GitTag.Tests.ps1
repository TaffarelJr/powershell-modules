#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a lightweight tag at HEAD
    New-GitTag -Name 'v1.0.0' -RepoPath $repo

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) -Actual (Resolve-GitRef -Ref 'v1.0.0' -RepoPath $repo) `
        -Message 'A lightweight tag points at HEAD by default'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second' 2>&1 | Out-Null
    $first = (git -C $repo rev-parse HEAD~1).Trim()

    # Act - a tag at an explicit, earlier ref
    New-GitTag -Name 'v0.9.0' -Ref $first -RepoPath $repo

    # Assert
    Assert-Equal -Expected $first -Actual (Resolve-GitRef -Ref 'v0.9.0' -RepoPath $repo) -Message 'A given -Ref is honored over HEAD'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an annotated tag
    New-GitTag -Name 'v1.1.0' -Message 'Release notes here' -RepoPath $repo

    # Assert - an annotated tag is its own object, distinct from the commit it marks
    $tagType = (git -C $repo cat-file -t 'v1.1.0').Trim()
    Assert-Equal -Expected 'tag' -Actual $tagType -Message '-Message creates an annotated tag, not a lightweight one'
    $tagLines = git -C $repo tag -l -n99 'v1.1.0'
    Assert-That -Condition (($tagLines -join "`n") -match 'Release notes here') `
        -Message 'The annotated tag carries the given message'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
