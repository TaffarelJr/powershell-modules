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
    $first = (git -C $repo rev-parse HEAD).Trim()
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'more' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second' 2>&1 | Out-Null

    # Act - the root is the first commit, not the current tip
    $root = @(Get-GitRootCommit -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $root.Count -Message 'A linear history has exactly one root'
    Assert-Equal -Expected $first -Actual $root[0] -Message 'The root is the very first commit'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked folder
    New-Item -ItemType Directory -Path (Join-Path $repo 'src') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'src/x.txt') -Value 'x' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add src' 2>&1 | Out-Null
    git -C $repo branch src 2>&1 | Out-Null

    # Act
    $fromBranch = @(Get-GitRootCommit -Ref 'src' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected @($first) -Actual $fromBranch -Message 'A ref named like a folder is read as the ref'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $warnings = @(Get-WarningOutput -ScriptBlock { Get-GitRootCommit -RepoPath $repo })

    # Assert
    Assert-Equal -Expected 0 -Actual $warnings.Count -Message 'A full clone gives no warning'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Get-GitRootCommit -Ref 'no-such-ref' -RepoPath $repo } `
        -MessageLike '*Finding the root commit failed*no-such-ref*' -Message 'A ref that does not exist throws'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository with no commits yet
$empty = New-GitTestRepo -NoCommit
try {
    # Act
    $none = @(Get-GitRootCommit -RepoPath $empty)

    # Assert
    Assert-Equal -Expected 0 -Actual $none.Count `
        -Message 'A repository with no commits has no root, and that is not an error'
}
finally {
    Remove-GitTestRepo -Path $empty
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a shallow clone of a history three commits long
$source = New-GitTestRepo
git -C $source commit --quiet --allow-empty -m 'second' 2>&1 | Out-Null
git -C $source commit --quiet --allow-empty -m 'third' 2>&1 | Out-Null
$shallow = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
git clone --quiet --depth 1 "file://$($source -replace '\\', '/')" $shallow 2>&1 | Out-Null
try {
    # Act
    $warned = @(Get-WarningOutput -ScriptBlock { Get-GitRootCommit -RepoPath $shallow })

    # Assert
    Assert-Equal -Expected 1 -Actual $warned.Count -Message 'A shallow clone gives a warning'
    Assert-That -Condition ($warned[0] -like 'This is a shallow clone*not the real root*') `
        -Message 'that says the commit is not the real root'
}
finally {
    Remove-GitTestRepo -Path $source
    Remove-GitTestRepo -Path $shallow
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare repository with no commits yet
$emptyBare = Join-Path ([System.IO.Path]::GetTempPath()) "bare-$([Guid]::NewGuid()).git"
git init --quiet --bare $emptyBare 2>&1 | Out-Null
try {
    # Act / Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitRootCommit -RepoPath $emptyBare).Count `
        -Message 'A bare repository with no commits has no root, and no error'
}
finally {
    Remove-GitTestRepo -Path $emptyBare
}

exit (Complete-TestRun)
