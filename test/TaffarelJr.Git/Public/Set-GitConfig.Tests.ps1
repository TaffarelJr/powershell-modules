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
    # Act
    Set-GitConfig -Name 'custom.value' -Value 'hello' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'hello' -Actual (Get-GitConfig -Name 'custom.value' -RepoPath $repo) -Message 'Sets a new config value'

    #───────────────────────────────────────────────────────────────────────────
    # Act - overwriting an existing value
    Set-GitConfig -Name 'custom.value' -Value 'updated' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'updated' -Actual (Get-GitConfig -Name 'custom.value' -RepoPath $repo) -Message 'Overwrites an existing value'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an empty value, which git itself treats as legitimate for some keys
    Set-GitConfig -Name 'custom.empty' -Value '' -RepoPath $repo

    # Assert
    Assert-Equal -Expected '' -Actual (Get-GitConfig -Name 'custom.empty' -RepoPath $repo) -Message 'Accepts and sets an empty value'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
