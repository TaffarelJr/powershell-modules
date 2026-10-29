#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the local repository from its parent
$fake = New-FakeGitHubCli
try {
    # Act
    Sync-GitHubRepository
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'sync') -Actual $call.Arguments `
        -Message 'Without options, the local repository syncs from its parent'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a remote fork from another repository, forced
$fake = New-FakeGitHubCli
try {
    # Act
    Sync-GitHubRepository -Destination 'me/fork' -Source 'o/r' -Branch 'v1' -Force
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'sync', 'me/fork', '--source', 'o/r', '--branch=v1', '--force') `
        -Actual $call.Arguments `
        -Message 'The destination is positional and each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the source given as a repository object, and a branch that starts with a dash
$fake = New-FakeGitHubCli
try {
    # Act
    Sync-GitHubRepository -Destination 'me/fork' -Source ([PSCustomObject]@{ NameWithOwner = 'o/r'; Name = 'r' })
    Sync-GitHubRepository -Destination 'me/fork' -Branch '-x'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'sync', 'me/fork', '--source', 'o/r') -Actual $calls[0].Arguments `
        -Message 'A source object is read by its NameWithOwner, not its text'
    Assert-Equal -Expected @('repo', 'sync', 'me/fork', '--branch=-x') -Actual $calls[1].Arguments `
        -Message 'A branch travels joined to its flag, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a destination or a source given as $null, as a lookup that found nothing gives
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination $null -Force
    } -MessageLike "-Destination was given, but it is `$null - leave it out to use the current directory's local repository." `
        -Message 'A $null destination throws, rather than hard-resetting the local clone'
    Assert-Throws -ScriptBlock {
        $null | Sync-GitHubRepository -Force
    } -MessageLike '-Destination was given, but it is $null*' -Message 'as does a piped $null'
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination 'me/fork' -Source $null
    } -MessageLike "-Source was given, but it is `$null - leave it out to use the destination's parent." `
        -Message 'and a $null source, rather than syncing from the parent'
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination 'me/fork' -Source '--force'
    } -MessageLike "*'--force' is not a repository*" -Message 'A source that is a gh option is refused'
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination 'me/fork' -Source @()
    } -MessageLike '-Source is an empty list: give one repository, or leave it out.' `
        -Message 'An empty list of sources names -Source, not -Repository'
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination 'me/fork' -Branch '' -Force
    } -MessageLike '-Branch was given but is blank, so the source''s default branch would be synced. Give a value, or leave -Branch off.' `
        -Message 'A blank branch is refused, not taken as the default branch'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh failing to sync a named repository and the local one
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 409: Conflict') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination 'me/fork'
    } -MessageLike 'Syncing repository me/fork failed*Conflict*' -Message 'A failure names the repository being synced'
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository
    } -MessageLike 'Syncing the current directory''s local repository failed*Conflict*' `
        -Message 'or says it was the local one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside every other parameter, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(
        Sync-GitHubRepository -Destination 'me/fork' -Source 'o/r' -Branch 'v1' -Force -WhatIf
        Sync-GitHubRepository -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so nothing is synced or reset'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Sync-GitHubRepository -Destination 'me/fork' -Source 'o/r' -Branch 'v1' -Force -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'sync', 'me/fork', '--source', 'o/r', '--branch=v1', '--force') `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false sync as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two destinations piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @('me/a', 'me/b' | Sync-GitHubRepository -Force -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped repository is synced'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a destination given as $null, and a blank branch
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination $null -Force -WhatIf
    } -MessageLike '-Destination was given, but it is $null*' -Message '-WhatIf still refuses a $null destination'
    Assert-Throws -ScriptBlock {
        Sync-GitHubRepository -Destination 'me/fork' -Branch ' ' -WhatIf
    } -MessageLike '-Branch was given but is blank*' -Message 'and a blank branch'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines: credentials in both URLs, and the local clone by its full path
$folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "sync-$([Guid]::NewGuid())")
$elsewhere = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "sync-$([Guid]::NewGuid())")
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Use-SplitLocation -Location $folder.FullName -ProcessDirectory $elsewhere.FullName -ScriptBlock {
            Sync-GitHubRepository -Destination 'https://x-access-token:SENTINEL@github.com/me/fork' `
                -Source 'https://u:SENTINEL@ghe.example.com/o/r' `
                -Branch 'v1' `
                -Force `
                -WhatIf
            Sync-GitHubRepository -WhatIf
        }
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Sync branch v1 from ghe.example.com/o/r, hard-resetting it if it has' +
        ' diverged" on target "me/fork".'
        "What if: Performing the operation `"Sync the default branch`" on target `"$($folder.FullName)`"."
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names both repositories without their credentials, and the local clone by its path'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two destinations piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock { 'me/a', 'me/b' | Sync-GitHubRepository -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Sync the default branch" on target "me/a".'
        'What if: Performing the operation "Sync the default branch" on target "me/b".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped destination gets its own line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
