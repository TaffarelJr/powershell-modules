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
    # Arrange / Act / Assert - the repo's own .git folder
    $gitDir = Get-GitDirectory -RepoPath $repo
    Assert-Equal -Expected "$($repo -replace '\\', '/')/.git" -Actual $gitDir -Message "Returns the repo's .git directory"
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath $gitDir -PathType Container) `
        -Message 'The returned path actually exists'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - not a repo at all
    $plain = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $plain | Out-Null
    try {
        Assert-Equal -Expected $null -Actual (Get-GitDirectory -RepoPath $plain) -Message 'A plain folder returns $null'
    }
    finally {
        Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
