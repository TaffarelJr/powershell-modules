#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Clear-GitHubConfigCache
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'clear-cache') -Actual $call.Arguments `
        -Message 'gh is asked to clear its own cache, with no further arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a cache gh cannot delete
$fake = New-FakeGitHubCli -ErrorOutput @('failed to clear cache: access is denied') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Clear-GitHubConfigCache
    } -MessageLike "*Clearing gh's cache failed*access is denied*" -Message 'A failure throws with gh''s reason'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock { Clear-GitHubConfigCache -WhatIf }

    # Assert
    $line = 'What if: Performing the operation "Clear cache" on target "gh''s local HTTP response cache".'
    Assert-Equal -Expected @($line) -Actual $whatIf.Messages `
        -Message '-WhatIf names the cache'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Clear-GitHubConfigCache -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'clear-cache') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
