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
    # Arrange / Act / Assert - a real repo
    Assert-Equal -Expected $true -Actual (Test-GitRepository -RepoPath $repo) -Message 'A real repo reports true'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a bare repository has no working tree, and git
    # says so with a success exit code
    $bare = Join-Path ([System.IO.Path]::GetTempPath()) "bare-$([Guid]::NewGuid()).git"
    git init --quiet --bare $bare 2>&1 | Out-Null

    # Assert
    try {
        Assert-Equal -Expected $false -Actual (Test-GitRepository -RepoPath $bare) `
            -Message 'A bare repository reports false'
    }
    finally {
        Remove-Item -LiteralPath $bare -Recurse -Force -ErrorAction SilentlyContinue
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - inside the repository's own .git folder
    Assert-Equal -Expected $false -Actual (Test-GitRepository -RepoPath (Join-Path $repo '.git')) `
        -Message 'The .git folder is not a working tree either'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a plain folder with no .git
    $plain = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $plain | Out-Null

    # Assert
    try {
        Assert-Equal -Expected $false -Actual (Test-GitRepository -RepoPath $plain) `
            -Message 'A plain folder reports false'
    }
    finally {
        Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
