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
    # Arrange - two new files
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline

    # Act - stage just one, by pathspec
    Add-GitChange -Path 'b.txt' -RepoPath $repo

    # Assert
    $status = @(Get-GitStatus -RepoPath $repo)
    $staged = @($status | Where-Object { $_.Status[0] -ne ' ' -and $_.Status[0] -ne '?' })
    Assert-Equal -Expected 1 -Actual $staged.Count -Message 'Only the given path is staged'
    Assert-Equal -Expected 'b.txt' -Actual $staged[0].Path -Message 'The staged path is the one given'

    #───────────────────────────────────────────────────────────────────────────
    # Act - stage everything else with no -Path
    Add-GitChange -RepoPath $repo

    # Assert
    $allStatus = @(Get-GitStatus -RepoPath $repo)
    $unstaged = @($allStatus | Where-Object { $_.Status[0] -eq ' ' -or $_.Status[0] -eq '?' })
    Assert-Equal -Expected 0 -Actual $unstaged.Count -Message 'Omitting -Path stages the entire working tree'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a third file, staged via the pipeline
    Set-Content -LiteralPath (Join-Path $repo 'd.txt') -Value 'd' -NoNewline

    # Act
    'd.txt' | Add-GitChange -RepoPath $repo

    # Assert
    $finalStatus = @(Get-GitStatus -RepoPath $repo)
    $dEntry = @($finalStatus | Where-Object Path -EQ 'd.txt')
    Assert-Equal -Expected 'A ' -Actual $dEntry[0].Status -Message 'A path piped in is staged'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - another file, staged by piping Get-GitStatus straight in
    Set-Content -LiteralPath (Join-Path $repo 'e.txt') -Value 'e' -NoNewline

    # Act
    Get-GitStatus -RepoPath $repo | Add-GitChange -RepoPath $repo

    # Assert
    $afterPipe = @(Get-GitStatus -RepoPath $repo)
    $eEntry = @($afterPipe | Where-Object Path -EQ 'e.txt')
    Assert-Equal -Expected 'A ' -Actual $eEntry[0].Status -Message 'Get-GitStatus pipes straight into Add-GitChange'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an untracked file that must stay out of the commit
    Set-Content -LiteralPath (Join-Path $repo 'secret.env') -Value 'TOKEN=abc' -NoNewline

    # Act - pipelines that come to nothing
    @() | Add-GitChange -RepoPath $repo
    Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'no-such-path' | Add-GitChange -RepoPath $repo

    # Assert
    $afterEmptyPipe = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'secret.env')
    Assert-Equal -Expected '??' -Actual $afterEmptyPipe[0].Status `
        -Message 'A pipeline that came to nothing stages nothing, not the whole tree'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an empty -Path
    Add-GitChange -Path @() -RepoPath $repo

    # Assert
    $afterEmptyPath = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'secret.env')
    Assert-Equal -Expected '??' -Actual $afterEmptyPath[0].Status -Message 'An empty -Path stages nothing either'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two untracked files, one named like a pattern the other matches
    Set-Content -LiteralPath (Join-Path $repo 'report[1].txt') -Value 'r' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'report1.txt') -Value 'SECRET' -NoNewline

    # Act
    Add-GitChange -Path 'report[1].txt' -RepoPath $repo

    # Assert
    $named = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'report[1].txt')
    $lookalike = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'report1.txt')
    Assert-Equal -Expected 'A ' -Actual $named[0].Status -Message 'A path holding pattern characters stages that file'
    Assert-Equal -Expected '??' -Actual $lookalike[0].Status -Message 'and not another file the pattern would match'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an untracked file in a subfolder, which is where PowerShell is
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/x.txt') -Value 'x' -NoNewline
    Push-Location -LiteralPath (Join-Path $repo 'sub')

    # Act
    try {
        Get-GitStatus | Where-Object Path -EQ 'sub/x.txt' | Add-GitChange
    }
    finally {
        Pop-Location
    }

    # Assert
    $fromSub = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'sub/x.txt')
    Assert-Equal -Expected 'A ' -Actual $fromSub[0].Status `
        -Message 'A path Get-GitStatus reports stages from a subfolder too, being relative to the root'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an untracked file named by its full path, with a lookalike
    Set-Content -LiteralPath (Join-Path $repo 'full[2].txt') -Value 'f' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'full2.txt') -Value 'SECRET' -NoNewline
    $item = Get-Item -LiteralPath (Join-Path $repo 'full[2].txt')

    # Act
    $item | Add-GitChange -RepoPath $repo

    # Assert
    $full = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'full[2].txt')
    $fullLookalike = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'full2.txt')
    Assert-Equal -Expected 'A ' -Actual $full[0].Status -Message 'A file piped from Get-Item is staged by its full path'
    Assert-Equal -Expected '??' -Actual $fullLookalike[0].Status -Message 'and literally, too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an untracked file named only by the PSPath of Get-Item output
    Set-Content -LiteralPath (Join-Path $repo 'pspath.txt') -Value 'p' -NoNewline
    $named = [PSCustomObject]@{
        PSPath = (Get-Item -LiteralPath (Join-Path $repo 'pspath.txt')).PSPath
    }

    # Act
    $named | Add-GitChange -RepoPath $repo

    # Assert
    $viaPsPath = @(Get-GitStatus -RepoPath $repo | Where-Object Path -EQ 'pspath.txt')
    Assert-Equal -Expected 'A ' -Actual $viaPsPath[0].Status `
        -Message 'An object with only a PSPath is bound through the PSPath alias, and its file is staged'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an edit to every file, each staged by a different form of path,
# typed from the subfolder 'sub', and one edit left alone
$repo = New-GitTestPathRepo `
    -Path 'sub/dot.txt', 'sub/abs.txt', 'sub/bare.txt', 'sub/inner.txt', 'up.txt', 'up2.txt', 'whole/w.txt', 'outside.txt'
try {
    foreach ($file in 'sub/dot.txt', 'sub/abs.txt', 'sub/bare.txt', 'sub/inner.txt', 'up.txt', 'up2.txt', 'whole/w.txt', 'outside.txt') {
        Set-Content -LiteralPath (Join-Path $repo $file) -Value 'edited' -NoNewline
    }

    $sub = Join-Path $repo 'sub'
    Push-Location -LiteralPath $sub

    # Act
    try {
        Add-GitChange -Path '.\dot.txt'
        Add-GitChange -Path '..\up.txt'
        Add-GitChange -Path (Join-Path $sub 'abs.txt')
        Add-GitChange -Path 'sub/bare.txt'
        Add-GitChange -Path 'sub/./inner.txt'
        Add-GitChange -Path 'sub/../up2.txt'
    }
    finally {
        Pop-Location
    }

    Add-GitChange -Path '.' -RepoPath (Join-Path $repo 'whole')

    # Assert
    $status = @(Get-GitStatus -RepoPath $repo)
    $rows = @(
        @{ Path = 'sub/dot.txt'; Expected = 'M '; Form = "'.\dot.txt', relative to the current location" }
        @{ Path = 'up.txt'; Expected = 'M '; Form = "'..\up.txt', relative to the current location" }
        @{ Path = 'sub/abs.txt'; Expected = 'M '; Form = 'an absolute path' }
        @{ Path = 'sub/bare.txt'; Expected = 'M '; Form = 'a bare path, relative to the repository root' }
        @{ Path = 'sub/inner.txt'; Expected = 'M '; Form = 'a bare path with an inner ''.''' }
        @{ Path = 'up2.txt'; Expected = 'M '; Form = 'a bare path with an inner ''..''' }
        @{ Path = 'whole/w.txt'; Expected = 'M '; Form = "'.', the folder -RepoPath names" }
        @{ Path = 'outside.txt'; Expected = ' M'; Form = 'no path at all' }
    )
    foreach ($row in $rows) {
        $entry = @($status | Where-Object Path -EQ $row.Path)
        Assert-Equal -Expected $row.Expected -Actual $entry[0].Status `
            -Message "$($row.Path), named by $($row.Form), is staged accordingly"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitChange -Path '\outside.txt' -RepoPath $sub } `
        -MessageLike '*Staging changes failed*outside repository*' `
        -Message 'A rooted path with no drive names the root of the drive, not the repository root'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
