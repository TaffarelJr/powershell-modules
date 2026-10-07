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
    # Arrange / Act / Assert - set by New-GitTestRepo itself
    Assert-Equal -Expected 'Test' -Actual (Get-GitConfig -Name 'user.name' -RepoPath $repo) -Message 'Reads an existing config value'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a key that was never set
    Assert-Equal -Expected $null -Actual (Get-GitConfig -Name 'not.a.real.key' -RepoPath $repo) -Message 'A missing key returns $null'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
