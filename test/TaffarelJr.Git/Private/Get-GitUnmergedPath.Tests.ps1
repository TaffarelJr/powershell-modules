#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestPathRepo -Path 'sub/x.txt', 'sub/other.txt'
try {
    git -C $repo checkout -q -b side 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from side' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'sub/x.txt') -Value 'from side' -NoNewline
    git -C $repo commit --quiet -am 'side' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from main' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'sub/x.txt') -Value 'from main' -NoNewline
    git -C $repo commit --quiet -am 'main' 2>&1 | Out-Null
    git -C $repo merge --no-edit side 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $all = @(& $module {
            param($Repo)
            Get-GitUnmergedPath -Pathspec ':(top)' -Activity 'Testing' -RepoPath $Repo
        } $repo)

    # Assert
    Assert-Equal -Expected @('a.txt', 'sub/x.txt') -Actual $all `
        -Message 'Each unmerged path comes back once, for all three of its stages, relative to the root'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $folder = @(& $module {
            param($Repo)
            Get-GitUnmergedPath -Pathspec ':(top,literal)sub' -Activity 'Testing' -RepoPath $Repo
        } $repo)

    # Assert
    Assert-Equal -Expected @('sub/x.txt') -Actual $folder `
        -Message 'A folder gives the unmerged paths inside it, and not the merged ones beside them'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $none = @(& $module {
            param($Repo)
            Get-GitUnmergedPath -Pathspec ':(top,literal)sub/other.txt' -Activity 'Testing' -RepoPath $Repo
        } $repo)

    # Assert
    Assert-Equal -Expected 0 -Actual $none.Count -Message 'A path with no conflict gives nothing'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { param($Repo) Get-GitUnmergedPath -Pathspec ':(top)' -Activity 'Testing' -RepoPath $Repo } $plain
    } -MessageLike 'Testing failed*not a git repository*' -Message 'A folder that is no repository throws'
}
finally {
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
