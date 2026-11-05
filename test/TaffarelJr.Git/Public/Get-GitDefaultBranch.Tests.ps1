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

$origin = New-GitTestRepo
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clone, which records origin's HEAD symref locally
    git clone --quiet $origin $clone 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected 'main' -Actual (Get-GitDefaultBranch -RepoPath $clone) `
        -Message "Reads the remote's default branch from the local HEAD symref"

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - the remote named by its alias
    Assert-Equal -Expected 'main' -Actual (Get-GitDefaultBranch -Remote 'origin' -RepoPath $clone) `
        -Message '-Remote names the remote, as everywhere else in the module'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a remote that does not exist
    $refused = "Asking nope for its default branch failed (exit 128): *'nope' does not appear to be a git repository*"
    Assert-Throws -ScriptBlock { Get-GitDefaultBranch -Name 'nope' -RepoPath $clone } -MessageLike $refused `
        -Message 'A remote that cannot be asked throws, with git''s reason, rather than answering $null'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the local symref gone, as after a one-branch fetch
    git -C $clone remote set-head origin --delete 2>&1 | Out-Null
    git -C $origin branch -m main trunk 2>&1 | Out-Null

    # Act / Assert - the remote itself is asked, in a form git does not translate
    Assert-Equal -Expected 'trunk' -Actual (Get-GitDefaultBranch -RepoPath $clone) `
        -Message 'Without the local symref, asks the remote, and reads whatever branch it names'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the same, with git writing its messages in another language
    $env:LANGUAGE = 'de'
    $env:LC_ALL = 'de_DE.UTF-8'

    # Assert
    try {
        Assert-Equal -Expected 'trunk' -Actual (Get-GitDefaultBranch -RepoPath $clone) `
            -Message 'The answer does not depend on the language git is set to speak'
    }
    finally {
        Remove-Item Env:LANGUAGE, Env:LC_ALL -ErrorAction SilentlyContinue
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a remote that has no branch yet, so no default to name
    $bare = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
    git init --quiet --bare $bare 2>&1 | Out-Null
    git -C $clone remote add empty $bare 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $null -Actual (Get-GitDefaultBranch -Name 'empty' -RepoPath $clone) `
        -Message 'A remote with no default branch returns $null'

    Remove-GitTestRepo -Path $bare

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - an option-like remote name
    Assert-Throws -ScriptBlock {
        Get-GitDefaultBranch -Name '--upload-pack=echo-not-run' -RepoPath $clone
    } -MessageLike "*starts with '-'*" -Message 'A remote starting with a dash is refused'
}
finally {
    Remove-GitTestRepo -Path $origin
    Remove-GitTestRepo -Path $clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Get-GitDefaultBranch -RepoPath $plain } `
        -MessageLike '*Reading the default branch failed (exit 128)*not a git repository*' `
        -Message 'A folder that is no repository throws rather than answering $null'
}
finally {
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
