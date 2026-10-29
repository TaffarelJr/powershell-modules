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
    # Arrange / Act / Assert - a tracked path, checked right now
    Assert-Equal -Expected $true -Actual (Test-GitPath -Path 'a.txt' -RepoPath $repo) `
        -Message 'A tracked path reports true'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a path that was never tracked
    Assert-Equal -Expected $false -Actual (Test-GitPath -Path 'nope.txt' -RepoPath $repo) `
        -Message 'An untracked path reports false'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - delete the file in a later commit
    $firstCommit = (git -C $repo rev-parse HEAD).Trim()
    Remove-Item -LiteralPath (Join-Path $repo 'a.txt')
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'remove a' 2>&1 | Out-Null

    # Act / Assert - not tracked now, but present at the earlier ref
    Assert-Equal -Expected $false -Actual (Test-GitPath -Path 'a.txt' -RepoPath $repo) `
        -Message 'A deleted path is no longer tracked now'
    Assert-Equal -Expected $true -Actual (Test-GitPath -Path 'a.txt' -Ref $firstCommit -RepoPath $repo) `
        -Message '-Ref finds it at the commit where it still existed'
    Assert-Equal -Expected $false -Actual (Test-GitPath -Path 'a.txt' -Ref 'HEAD' -RepoPath $repo) `
        -Message '-Ref at the current commit correctly reports it missing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tracked file in a subfolder, which is where PowerShell is
    New-Item -ItemType Directory -Path (Join-Path $repo 'src') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'src/x.txt') -Value 'x' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add x' 2>&1 | Out-Null
    Push-Location -LiteralPath (Join-Path $repo 'src')

    # Act
    try {
        $now = Test-GitPath -Path 'src/x.txt'
        $atHead = Test-GitPath -Path 'src/x.txt' -Ref 'HEAD'
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $true -Actual $now `
        -Message 'A path relative to the repository root is found from a subfolder'
    Assert-Equal -Expected $true -Actual $atHead -Message 'and the same with -Ref'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $backslashed = Test-GitPath -Path 'src\x.txt' -RepoPath $repo
    $backslashedAtHead = Test-GitPath -Path 'src\x.txt' -Ref 'HEAD' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $backslashed -Message 'A backslash is read as a forward slash'
    Assert-Equal -Expected $true -Actual $backslashedAtHead -Message 'with -Ref as well'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $pattern = Test-GitPath -Path 'src/*.txt' -RepoPath $repo
    $patternAtHead = Test-GitPath -Path 'src/*.txt' -Ref 'HEAD' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $pattern -Message 'A pattern is a name, and no file has that name'
    Assert-Equal -Expected $false -Actual $patternAtHead -Message 'with -Ref as well'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $folder = Test-GitPath -Path 'src' -RepoPath $repo
    $absolute = Test-GitPath -Path (Join-Path $repo 'src/x.txt') -Ref 'HEAD' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $folder -Message 'A folder holding a tracked file exists'
    Assert-Equal -Expected $true -Actual $absolute -Message 'and an absolute path is found too'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that does not exist
    Assert-Throws -ScriptBlock { Test-GitPath -Path 'a.txt' -Ref 'no-such-ref' -RepoPath $repo } `
        -MessageLike '*Checking a.txt at no-such-ref failed*' `
            -Message 'A ref that does not exist throws rather than reading as $false'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Test-GitPath -Path 'a.txt' -RepoPath $plain } `
        -MessageLike '*Checking a.txt failed (exit 128)*not a git repository*' `
            -Message 'A folder that is no repository throws rather than reading as $false'
}
finally {
    Remove-GitTestRepo -Path $plain
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - tracked files, named by every form of path from the subfolder 'sub'
$repo = New-GitTestPathRepo -Path 'sub/x.txt', 'up.txt'
$sub = Join-Path $repo 'sub'
$rows = @(
    @{ Path = '.\x.txt'; Expected = $true; Form = "'.\x.txt', relative to the current location" }
    @{ Path = '..\up.txt'; Expected = $true; Form = "'..\up.txt', relative to the current location" }
    @{ Path = (Join-Path $sub 'x.txt'); Expected = $true; Form = 'an absolute path' }
    @{ Path = 'sub/x.txt'; Expected = $true; Form = 'a bare path, relative to the repository root' }
    @{ Path = 'sub/./x.txt'; Expected = $true; Form = 'a bare path with an inner ''.''' }
    @{ Path = 'sub/../up.txt'; Expected = $true; Form = 'a bare path with an inner ''..''' }
    @{ Path = '.'; Expected = $true; Form = "'.', the current folder" }
    @{ Path = '.\up.txt'; Expected = $false; Form = "'.\up.txt', which is not in the current folder" }
)
Push-Location -LiteralPath $sub

# Act / Assert
try {
    foreach ($row in $rows) {
        Assert-Equal -Expected $row.Expected -Actual (Test-GitPath -Path $row.Path) `
            -Message "$($row.Form) is checked where it points"
        Assert-Equal -Expected $row.Expected -Actual (Test-GitPath -Path $row.Path -Ref 'HEAD') `
            -Message 'and at a ref, too'
    }
}
finally {
    Pop-Location
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
