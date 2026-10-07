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
    # Arrange / Act / Assert - set by New-GitTestRepo itself
    Assert-Equal -Expected 'Test' -Actual (Get-GitConfig -Name 'user.name' -RepoPath $repo) `
        -Message 'Reads an existing config value'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a key that was never set
    Assert-Equal -Expected $null -Actual (Get-GitConfig -Name 'not.a.real.key' -RepoPath $repo) `
        -Message 'A missing key returns $null'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a key git cannot read at all is an error, not "unset"
    Assert-Throws -ScriptBlock {
        Get-GitConfig -Name 'nodot' -RepoPath $repo
    } -MessageLike '*Reading nodot failed*' -Message 'An invalid key name throws, with git''s own message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - an empty value is a value
    git -C $repo config custom.empty '' 2>&1 | Out-Null

    # Assert
    Assert-Equal -Expected '' -Actual (Get-GitConfig -Name 'custom.empty' -RepoPath $repo) `
        -Message 'An empty value comes back as an empty string, not $null'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a value with surrounding spaces, kept exactly
    Set-GitConfig -Name 'custom.spaced' -Value '  padded  ' -RepoPath $repo

    # Assert
    Assert-Equal -Expected '  padded  ' -Actual (Get-GitConfig -Name 'custom.spaced' -RepoPath $repo) `
        -Message 'A value keeps its surrounding spaces'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - an option-like name
    Assert-Throws -ScriptBlock {
        Get-GitConfig -Name '--list' -RepoPath $repo
    } -MessageLike "*'--list' is blank or starts with '-'*" -Message 'A name starting with a dash is refused'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the global config, a throwaway file rather than the real one
$globalConfig = New-GitTestGlobalConfig
try {
    # Act
    Set-GitConfig -Name 'custom.global' -Value 'from-global' -Global
    $fromGlobal = Get-GitConfig -Name 'custom.global' -Global

    # Assert
    Assert-Equal -Expected 'from-global' -Actual $fromGlobal -Message '-Global reads what Set-GitConfig -Global wrote'
    Assert-That -Condition ((Get-Content -LiteralPath $globalConfig -Raw) -like '*from-global*') `
        -Message 'It went to the global config file'
    Assert-Equal -Expected $null -Actual (Get-GitConfig -Name 'custom.not-there' -Global) `
        -Message '-Global still answers $null for a key that is not set'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a -RepoPath that does not exist
    $missing = Join-Path ([System.IO.Path]::GetTempPath()) "missing-$([Guid]::NewGuid())"

    # Act
    Set-GitConfig -Name 'custom.anywhere' -Value 'yes' -Global -RepoPath $missing
    $fromAnywhere = Get-GitConfig -Name 'custom.anywhere' -Global -RepoPath $missing

    # Assert
    Assert-Equal -Expected 'yes' -Actual $fromAnywhere `
        -Message '-Global does not use -RepoPath, so a folder that is not there does not matter'
}
finally {
    Remove-GitTestGlobalConfig -Path $globalConfig
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value set globally and not in the repo
$globalConfig = New-GitTestGlobalConfig
$repo = New-GitTestRepo
try {
    git config --global custom.layered 'from-global' 2>&1 | Out-Null

    # Act
    $effective = Get-GitConfig -Name 'custom.layered' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'from-global' -Actual $effective `
        -Message 'Without -Global, the value in effect in the repo comes back, from any scope'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestGlobalConfig -Path $globalConfig
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value set globally, read from a folder that is no repository
$globalConfig = New-GitTestGlobalConfig
$plain = New-GitTestFolder
try {
    git config --global custom.outside 'from-global' 2>&1 | Out-Null

    # Act
    $outside = Get-GitConfig -Name 'custom.outside' -RepoPath $plain
    $unsetOutside = Get-GitConfig -Name 'custom.not-there' -RepoPath $plain

    # Assert
    Assert-Equal -Expected 'from-global' -Actual $outside `
        -Message 'Outside a repository, the global value comes back rather than an error'
    Assert-Equal -Expected $null -Actual $unsetOutside -Message 'and a key set nowhere is $null there too'
}
finally {
    Remove-GitTestRepo -Path $plain
    Remove-GitTestGlobalConfig -Path $globalConfig
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - configuration handed down through the environment, as a CI setup
# passes an auth header
$repo = New-GitTestRepo
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'custom.fromenv'
$env:GIT_CONFIG_VALUE_0 = 'from-environment'

# Act
try {
    $fromEnvironment = Get-GitConfig -Name 'custom.fromenv' -RepoPath $repo
}
finally {
    Remove-Item -LiteralPath Env:GIT_CONFIG_COUNT, Env:GIT_CONFIG_KEY_0, Env:GIT_CONFIG_VALUE_0
    Remove-GitTestRepo -Path $repo
}

# Assert
Assert-Equal -Expected 'from-environment' -Actual $fromEnvironment `
    -Message 'Configuration passed through the environment still reaches git with -RepoPath'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an inherited GIT_CONFIG, and a throwaway global config
$globalConfig = New-GitTestGlobalConfig
$otherFile = Join-Path ([System.IO.Path]::GetTempPath()) "git-other-$([Guid]::NewGuid()).config"
New-Item -ItemType File -Path $otherFile | Out-Null
git config --global custom.globalenv 'global' 2>&1 | Out-Null
$env:GIT_CONFIG = $otherFile

# Act
try {
    $readGlobal = Get-GitConfig -Name 'custom.globalenv' -Global
}
finally {
    Remove-Item -LiteralPath Env:GIT_CONFIG
}


# Assert
try {
    Assert-Equal -Expected 'global' -Actual $readGlobal `
        -Message '-Global reads the global config though GIT_CONFIG is inherited'
}
finally {
    Remove-GitTestGlobalConfig -Path $globalConfig
    Remove-Item -LiteralPath $otherFile -Force
}

exit (Complete-TestRun)
