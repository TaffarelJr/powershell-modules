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
    # Arrange - a second commit with a multi-paragraph body
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second commit' -m 'A body explaining why.' 2>&1 | Out-Null
    $second = (git -C $repo rev-parse HEAD).Trim()

    # Act - the default order is newest first
    $log = @(Get-GitLog -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 2 -Actual $log.Count -Message 'Every commit is returned'
    Assert-Equal -Expected $second -Actual $log[0].Hash -Message 'Newest first by default'
    Assert-Equal -Expected 'second commit' -Actual $log[0].Subject -Message 'Subject is parsed correctly'
    Assert-Equal -Expected 'A body explaining why.' -Actual $log[0].Body -Message 'Body is parsed correctly'
    Assert-Equal -Expected 'Test' -Actual $log[0].Author -Message 'Author is parsed correctly'
    Assert-Equal -Expected 'test@example.com' -Actual $log[0].Email -Message 'Email is parsed correctly'
    Assert-Equal -Expected 'initial' -Actual $log[1].Subject -Message 'The earlier commit comes second'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Reverse returns oldest first
    $reversed = @(Get-GitLog -Reverse -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 'initial' -Actual $reversed[0].Subject -Message '-Reverse puts the oldest commit first'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Count limits the result
    $limited = @(Get-GitLog -Count 1 -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $limited.Count -Message '-Count limits how many commits come back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a third commit touching a different file
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'third commit' 2>&1 | Out-Null

    # Act - -Path scopes the log to commits touching that file
    $scoped = @(Get-GitLog -Path 'b.txt' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $scoped.Count -Message '-Path only returns commits touching that path'
    Assert-Equal -Expected 'second commit' -Actual $scoped[0].Subject -Message 'The right commit is returned'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a commit by someone with a non-ASCII name, in a repo told to
    # write its log in another encoding
    git -C $repo -c user.name="Ren$([char]0xE9)e" commit --quiet --allow-empty -m 'accented author' 2>&1 | Out-Null
    git -C $repo config i18n.logOutputEncoding ISO-8859-1 2>&1 | Out-Null

    # Act
    $accented = @(Get-GitLog -Count 1 -RepoPath $repo)

    # Assert
    Assert-Equal -Expected "Ren$([char]0xE9)e" -Actual $accented[0].Author `
        -Message 'The log is read as UTF-8 whatever i18n.logOutputEncoding says'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a signed commit, in a repo set to show signatures in its log,
    # which puts the verification text in front of the commit it belongs to
    $fakeGpg = Install-FakeGpg -Repo $repo
    Set-Content -LiteralPath (Join-Path $repo 'signed.txt') -Value 's' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -S -m 'a signed commit' 2>&1 | Out-Null
    git -C $repo config log.showSignature true 2>&1 | Out-Null
    $signedHash = (git -C $repo rev-parse HEAD).Trim()
    $rawLog = (git -C $repo log -1 '--format=%H' 2>&1) -join "`n"

    # Act
    $signed = @(Get-GitLog -Count 1 -RepoPath $repo)

    # Assert
    Assert-That -Condition ($rawLog -like '*Good signature*') `
        -Message 'Precondition: git itself puts signature text in front of the record'
    Assert-Equal -Expected $signedHash -Actual $signed[0].Hash `
        -Message 'A configured log.showSignature does not end up in the parsed hash'
    Assert-Equal -Expected 'a signed commit' -Actual $signed[0].Subject -Message 'or anywhere else in the commit'
    git -C $repo config --unset log.showSignature 2>&1 | Out-Null
    Remove-Item -LiteralPath $fakeGpg -Force

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a message holding the two ASCII separator characters
    $odd = "keep $([char]0x1E) the record and $([char]0x1F) the unit separators"
    git -C $repo commit --quiet --allow-empty -m "separators in $([char]0x1F) the subject" -m $odd 2>&1 | Out-Null

    # Act
    $separated = @(Get-GitLog -Count 2 -RepoPath $repo)

    # Assert
    Assert-Equal -Expected "separators in $([char]0x1F) the subject" -Actual $separated[0].Subject `
        -Message 'A subject holding a separator character comes back whole'
    Assert-Equal -Expected $odd -Actual $separated[0].Body -Message 'and so does a body holding both'
    Assert-Equal -Expected 'a signed commit' -Actual $separated[1].Subject `
        -Message 'and the commit before it is its own'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a range that does not exist is an error, not an empty history
    Assert-Throws -ScriptBlock {
        Get-GitLog -Range 'no-such-ref..HEAD' -RepoPath $repo
    } -MessageLike '*Reading commit history failed*' -Message 'A bad range throws, with git''s message'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - values git would read as options, and a count that cannot be
    Assert-Throws -ScriptBlock {
        Get-GitLog -Range '--output=somewhere' -RepoPath $repo
    } -MessageLike "*'--output=somewhere' is blank or starts with '-'*" `
        -Message 'A range starting with a dash is refused, so git cannot be made to write a file'
    Assert-Throws -ScriptBlock {
        Get-GitLog -Count -1 -RepoPath $repo
    } -MessageLike '*Count*' -Message 'A negative -Count is refused rather than ignored'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file named with pattern characters and a lookalike, each
    # committed on its own, in a subfolder, which is where PowerShell is
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/r[1].txt') -Value 'r' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add the bracketed file' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/r1.txt') -Value 'r' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add the lookalike' 2>&1 | Out-Null
    Push-Location -LiteralPath (Join-Path $repo 'sub')

    # Act
    try {
        $literal = @(Get-GitLog -Path 'sub/r[1].txt')
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected @('add the bracketed file') -Actual @($literal | ForEach-Object Subject) `
        -Message '-Path is literal and relative to the repository root, from a subfolder too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked folder
    git -C $repo branch sub 2>&1 | Out-Null

    # Act
    $byBranch = @(Get-GitLog -Range 'sub' -Count 1 -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 'add the lookalike' -Actual $byBranch[0].Subject `
        -Message 'A range named like a folder is read as the ref'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository with no commits yet, and a folder that is no repository
$empty = New-GitTestRepo -NoCommit
$plain = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $plain | Out-Null
try {
    # Act / Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitLog -RepoPath $empty).Count `
        -Message 'A repository with no commits has an empty history, not an error'
    Assert-Throws -ScriptBlock {
        Get-GitLog -RepoPath $plain
    } -MessageLike '*Reading commit history failed*not a git repository*' `
        -Message 'A folder that is no repository still throws'
}
finally {
    Remove-GitTestRepo -Path $empty
    Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a two-commit repository, and an inherited GIT_SHALLOW_FILE that
# would cut its history at the newest commit
$repo = New-GitTestRepo
git -C $repo commit --quiet --allow-empty -m 'second' 2>&1 | Out-Null
$shallowFile = Join-Path ([System.IO.Path]::GetTempPath()) "git-shallow-$([Guid]::NewGuid())"
Set-Content -LiteralPath $shallowFile -Value (git -C $repo rev-parse HEAD)
$env:GIT_SHALLOW_FILE = $shallowFile

# Act
try {
    $whole = @(Get-GitLog -RepoPath $repo)
}
finally {
    Remove-Item -LiteralPath Env:GIT_SHALLOW_FILE
    Remove-Item -LiteralPath $shallowFile -Force
    Remove-GitTestRepo -Path $repo
}

# Assert
Assert-Equal -Expected 2 -Actual $whole.Count `
    -Message 'With -RepoPath, an inherited GIT_SHALLOW_FILE cannot cut the history short'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare repository with no commits yet
$emptyBare = Join-Path ([System.IO.Path]::GetTempPath()) "bare-$([Guid]::NewGuid()).git"
git init --quiet --bare $emptyBare 2>&1 | Out-Null
try {
    # Act / Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitLog -RepoPath $emptyBare).Count `
        -Message 'A bare repository with no commits has an empty history too'
}
finally {
    Remove-GitTestRepo -Path $emptyBare
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a second commit that touches only up.txt, so each path has its own
# history, read by every form of path from the subfolder 'sub'
$repo = New-GitTestPathRepo -Path 'sub/x.txt', 'up.txt'
$sub = Join-Path $repo 'sub'
Set-Content -LiteralPath (Join-Path $repo 'up.txt') -Value 'edited' -NoNewline
git -C $repo commit --quiet -am 'edit up' 2>&1 | Out-Null
$rows = @(
    @{ Path = '.\x.txt'; Expected = 'add path files'; Form = "'.\x.txt', relative to the current location" }
    @{
        Path = '..\up.txt'
        Expected = 'edit up, add path files'
        Form = "'..\up.txt', relative to the current location"
    }
    @{ Path = (Join-Path $sub 'x.txt'); Expected = 'add path files'; Form = 'an absolute path' }
    @{ Path = 'sub/x.txt'; Expected = 'add path files'; Form = 'a bare path, relative to the repository root' }
    @{ Path = '.'; Expected = 'add path files'; Form = "'.', the current folder" }
)
Push-Location -LiteralPath $sub

# Act / Assert
try {
    foreach ($row in $rows) {
        $log = @(Get-GitLog -Path $row.Path)
        Assert-Equal -Expected $row.Expected -Actual ($log.ForEach('Subject') -join ', ') `
            -Message "$($row.Form) scopes the log to where it points"
    }
}
finally {
    Pop-Location
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
