#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$source = New-GitTestRepo
$destination = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    Copy-GitRepository -Url $source -Destination $destination

    # Assert
    Assert-Equal -Expected $true -Actual (Test-GitRepository -RepoPath $destination) -Message 'The destination is a real git repo'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $source) -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $destination) `
        -Message 'The clone has the same history as the source'
    Assert-Equal -Expected $source -Actual (Get-GitRemote -Name 'origin' -RepoPath $destination) `
        -Message "The clone's origin points back at the source"
}
finally {
    Remove-GitTestRepo -Path $source
    Remove-GitTestRepo -Path $destination
}

exit (Complete-TestRun)
