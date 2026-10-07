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
    # Arrange - an unstaged change
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline

    # Act - the default diffs the working tree
    $diff = @(Get-GitDiff -RepoPath $repo)

    # Assert
    Assert-That -Condition (($diff -join "`n") -match 'a\.txt') `
        -Message 'The default diffs the working tree against HEAD'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - stage it
    git -C $repo add -A 2>&1 | Out-Null

    # Act - -Staged diffs the index instead
    $staged = @(Get-GitDiff -Staged -NameOnly -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 'a.txt' -Actual ($staged -join '') -Message '-Staged -NameOnly lists just the staged path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second commit
    git -C $repo commit --quiet -m 'change a' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'new' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add b' 2>&1 | Out-Null

    # Act - -NameStatus between two refs
    $nameStatus = @(Get-GitDiff -FromRef 'HEAD~2' -ToRef 'HEAD' -NameStatus -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 2 -Actual $nameStatus.Count -Message 'Both changed paths are listed'
    Assert-That -Condition (($nameStatus -join "`n") -match '^[AM]\t') -Message 'Status letters are included'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Path scopes the diff to one file
    $scoped = @(Get-GitDiff -FromRef 'HEAD~2' -ToRef 'HEAD' -NameOnly -Path 'b.txt' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 'b.txt' -Actual ($scoped -join '') -Message '-Path scopes the result to that file alone'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - the two path listings cannot be asked for together
    Assert-Throws -ScriptBlock {
        Get-GitDiff -FromRef 'HEAD~1' -ToRef 'HEAD' -NameOnly -NameStatus -RepoPath $repo
    } -MessageLike '*Parameter set cannot be resolved*' `
        -Message '-NameOnly and -NameStatus together are refused, not one quietly winning'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a user config that colors every diff, and names an external diff tool
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'newer' -NoNewline
    git -C $repo config color.ui always 2>&1 | Out-Null
    git -C $repo config diff.external 'no-such-diff-tool' 2>&1 | Out-Null

    # Act
    $plain = @(Get-GitDiff -RepoPath $repo)

    # Assert
    Assert-That -Condition (($plain -join "`n") -match '\+newer') `
        -Message 'The patch text is produced even with an external diff tool configured'
    Assert-That -Condition (($plain -join "`n") -notmatch "$([char]27)\[") `
        -Message 'and carries no color escape sequences'
    git -C $repo config --unset color.ui 2>&1 | Out-Null
    git -C $repo config --unset diff.external 2>&1 | Out-Null
    git -C $repo checkout -- b.txt 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a changed file whose name git would escape
    $accented = "caf$([char]0xE9) au lait.txt"
    Set-Content -LiteralPath (Join-Path $repo $accented) -Value 'v1' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add accented' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo $accented) -Value 'v2' -NoNewline
    git -C $repo commit --quiet -am 'change accented' 2>&1 | Out-Null

    # Act
    $names = @(Get-GitDiff -FromRef 'HEAD~1' -ToRef 'HEAD' -NameOnly -RepoPath $repo)
    $statuses = @(Get-GitDiff -FromRef 'HEAD~1' -ToRef 'HEAD' -NameStatus -RepoPath $repo)

    # Assert
    Assert-Equal -Expected $accented -Actual $names[0] -Message '-NameOnly writes a non-ASCII path as it is on disk'
    Assert-Equal -Expected "M`t$accented" -Actual $statuses[0] -Message '-NameStatus does too'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref git would read as an option
    Assert-Throws -ScriptBlock {
        Get-GitDiff -FromRef '--output=somewhere' -RepoPath $repo
    } -MessageLike "*'--output=somewhere' is blank or starts with '-'*" `
        -Message 'A ref starting with a dash is refused, so git cannot be made to write a file'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file named with pattern characters and its lookalike, both
    # changed in a subfolder, which is where PowerShell is
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/r[1].txt') -Value 'r' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'sub/r1.txt') -Value 'r' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add r files' 2>&1 | Out-Null
    Push-Location -LiteralPath (Join-Path $repo 'sub')

    # Act
    try {
        $literal = @(Get-GitDiff -FromRef 'HEAD~1' -ToRef 'HEAD' -NameOnly -Path 'sub/r[1].txt')
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected @('sub/r[1].txt') -Actual $literal `
        -Message '-Path is literal and relative to the repository root, from a subfolder too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked folder
    git -C $repo branch sub 2>&1 | Out-Null

    # Act
    $byBranch = @(Get-GitDiff -FromRef 'sub' -ToRef 'HEAD' -NameOnly -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 0 -Actual $byBranch.Count -Message 'A ref named like a folder is read as the ref'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a textconv driver that leaves a mark when git runs it
    $recorder = New-GitTestRecorder
    Set-Content -LiteralPath (Join-Path $repo '.gitattributes') -Value '*.bin diff=probe' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'data.bin') -Value 'one' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add data' 2>&1 | Out-Null
    git -C $repo config diff.probe.textconv $recorder.Program 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'data.bin') -Value 'two' -NoNewline

    # Act
    $converted = @(Get-GitDiff -RepoPath $repo)

    # Assert
    Assert-That -Condition (($converted -join "`n") -match '\+two') -Message 'The patch shows the file''s own content'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $recorder.Log) `
        -Message 'and a configured textconv program is not run'
    git -C $repo config --unset diff.probe.textconv 2>&1 | Out-Null
    Remove-Item -LiteralPath $recorder.Program, $recorder.Log -Force -ErrorAction SilentlyContinue
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - unstaged edits in and outside the subfolder 'sub', diffed by every
# form of path from inside it
$repo = New-GitTestPathRepo -Path 'sub/x.txt', 'up.txt'
$sub = Join-Path $repo 'sub'
Set-Content -LiteralPath (Join-Path $sub 'x.txt') -Value 'edited' -NoNewline
Set-Content -LiteralPath (Join-Path $repo 'up.txt') -Value 'edited' -NoNewline
$rows = @(
    @{ Path = '.\x.txt'; Expected = 'sub/x.txt'; Form = "'.\x.txt', relative to the current location" }
    @{ Path = '..\up.txt'; Expected = 'up.txt'; Form = "'..\up.txt', relative to the current location" }
    @{ Path = (Join-Path $sub 'x.txt'); Expected = 'sub/x.txt'; Form = 'an absolute path' }
    @{ Path = 'sub/x.txt'; Expected = 'sub/x.txt'; Form = 'a bare path, relative to the repository root' }
    @{ Path = '.'; Expected = 'sub/x.txt'; Form = "'.', the current folder alone" }
)
Push-Location -LiteralPath $sub

# Act / Assert
try {
    foreach ($row in $rows) {
        $names = @(Get-GitDiff -NameOnly -Path $row.Path) -join ', '
        Assert-Equal -Expected $row.Expected -Actual $names -Message "$($row.Form) scopes the diff to where it points"
    }
}
finally {
    Pop-Location
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository whose config asks for other prefixes on the header
# lines, and an unstaged edit
$rows = @(
    @{ Setting = 'diff.mnemonicPrefix'; Shown = 'i/ and w/' }
    @{ Setting = 'diff.noprefix'; Shown = 'no prefix at all' }
)

# Act / Assert
foreach ($row in $rows) {
    $repo = New-GitTestRepo
    try {
        git -C $repo config $row.Setting true 2>&1 | Out-Null
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
        $headers = @(Get-GitDiff -RepoPath $repo | Where-Object { $_ -match '^(diff --git|---|\+\+\+) ' })
        Assert-Equal -Expected @('diff --git a/a.txt b/a.txt', '--- a/a.txt', '+++ b/a.txt') -Actual $headers `
            -Message "The header lines name the sides a/ and b/, whatever $($row.Setting) asks for ($($row.Shown))"
    }
    finally {
        Remove-GitTestRepo -Path $repo
    }
}

exit (Complete-TestRun)
