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
    # Act
    Set-GitConfig -Name 'custom.value' -Value 'hello' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'hello' -Actual (Get-GitConfig -Name 'custom.value' -RepoPath $repo) `
        -Message 'Sets a new config value'

    #───────────────────────────────────────────────────────────────────────────
    # Act - overwriting an existing value
    Set-GitConfig -Name 'custom.value' -Value 'updated' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'updated' -Actual (Get-GitConfig -Name 'custom.value' -RepoPath $repo) `
        -Message 'Overwrites an existing value'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an empty value, which git itself treats as legitimate for some keys
    Set-GitConfig -Name 'custom.empty' -Value '' -RepoPath $repo

    # Assert
    Assert-Equal -Expected '' -Actual (Get-GitConfig -Name 'custom.empty' -RepoPath $repo) `
        -Message 'Accepts and sets an empty value'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an inherited GIT_CONFIG that points git config at another file
$repo = New-GitTestRepo
$otherFile = Join-Path ([System.IO.Path]::GetTempPath()) "git-other-$([Guid]::NewGuid()).config"
New-Item -ItemType File -Path $otherFile | Out-Null
$env:GIT_CONFIG = $otherFile

# Act
try {
    Set-GitConfig -Name 'custom.written' -Value 'here' -RepoPath $repo
    $readBack = Get-GitConfig -Name 'user.name' -RepoPath $repo
}
finally {
    Remove-Item -LiteralPath Env:GIT_CONFIG
}

$inRepo = (git -C $repo config --local --get custom.written) -join ''
$inOther = [System.IO.File]::ReadAllText($otherFile)

# Assert
try {
    Assert-Equal -Expected 'here' -Actual $inRepo `
        -Message 'With -RepoPath, the value goes to the repository''s own config'
    Assert-Equal -Expected '' -Actual $inOther -Message 'and not to the file an inherited GIT_CONFIG names'
    Assert-Equal -Expected 'Test' -Actual $readBack `
        -Message 'and Get-GitConfig -RepoPath reads the repository''s config too'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-Item -LiteralPath $otherFile -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an inherited GIT_CONFIG, and a throwaway global config
$globalConfig = New-GitTestGlobalConfig
$otherFile = Join-Path ([System.IO.Path]::GetTempPath()) "git-other-$([Guid]::NewGuid()).config"
New-Item -ItemType File -Path $otherFile | Out-Null
$env:GIT_CONFIG = $otherFile

# Act
try {
    Set-GitConfig -Name 'custom.globalenv' -Value 'global' -Global
}
finally {
    Remove-Item -LiteralPath Env:GIT_CONFIG
}

$inGlobal = (git config --global --get custom.globalenv) -join ''

# Assert
try {
    Assert-Equal -Expected 'global' -Actual $inGlobal `
        -Message '-Global writes the global config though GIT_CONFIG is inherited'
    Assert-Equal -Expected '' -Actual ([System.IO.File]::ReadAllText($otherFile)) `
        -Message 'and nothing goes to the file GIT_CONFIG names'
}
finally {
    Remove-GitTestGlobalConfig -Path $globalConfig
    Remove-Item -LiteralPath $otherFile -Force
}

exit (Complete-TestRun)
