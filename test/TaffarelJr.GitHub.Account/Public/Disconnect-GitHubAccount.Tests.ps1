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
    Disconnect-GitHubAccount -User 'me' -Hostname 'ghe.example'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'logout', '--user', 'me', '--hostname', 'ghe.example') -Actual $call.Arguments `
        -Message '-User and -Hostname become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the only stored account, nothing to disambiguate
$fake = New-FakeGitHubCli
try {
    # Act
    Disconnect-GitHubAccount
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'logout') -Actual $call.Arguments `
        -Message 'Without options, gh is left to pick the one account'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several accounts and none named, which gh cannot ask about here
$reason = 'unable to determine which account to log out of, please specify `--hostname` and `--user`'
$fake = New-FakeGitHubCli -ErrorOutput @($reason) -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Disconnect-GitHubAccount
    } -MessageLike '*Logging out failed*unable to determine which account*' `
        -Message 'An ambiguous logout throws with gh''s reason'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Disconnect-GitHubAccount -User 'me' -Hostname 'ghe.example' -WhatIf
        Disconnect-GitHubAccount -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Remove gh login" on target "me on ghe.example".'
        'What if: Performing the operation "Remove gh login" on target "the only account on gh''s default host".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the account and its host, or says gh picks them'
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
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Disconnect-GitHubAccount -User 'a b' -WhatIf
    } -MessageLike "*'a b' is not an account name:*" -Message 'With -WhatIf, a bad account name is still refused'

    # Act
    Disconnect-GitHubAccount -User 'me' -Hostname 'ghe.example' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'logout', '--user', 'me', '--hostname', 'ghe.example') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
