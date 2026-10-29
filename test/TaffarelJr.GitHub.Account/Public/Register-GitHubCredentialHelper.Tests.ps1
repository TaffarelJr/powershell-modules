#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubAccountTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Register-GitHubCredentialHelper
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'setup-git') -Actual $call.Arguments `
        -Message 'Every logged-in host is configured by default'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one host, forced
$fake = New-FakeGitHubCli
try {
    # Act
    Register-GitHubCredentialHelper -Hostname 'ghe.example' -Force
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'setup-git', '--hostname', 'ghe.example', '--force') -Actual $call.Arguments `
        -Message '-Hostname and -Force become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one host, not forced
$fake = New-FakeGitHubCli
try {
    # Act
    Register-GitHubCredentialHelper -Hostname 'ghe.example'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'setup-git', '--hostname', 'ghe.example') -Actual $call.Arguments `
        -Message '-Hostname alone configures that host'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - forced, but with no host to force, which gh refuses
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-HostlessScript -Script 'Register-GitHubCredentialHelper -Force'
    } -MessageLike '*missing mandatory parameters: Hostname.*' `
        -Message '-Force without -Hostname is refused by PowerShell, which asks for the host'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no host gh is logged in to
$reason = 'You are not logged into any GitHub hosts. To log in, run: gh auth login'
$fake = New-FakeGitHubCli -ErrorOutput @($reason) -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Register-GitHubCredentialHelper
    } -MessageLike '*Configuring git to use gh for credentials failed*not logged into any GitHub hosts*' `
        -Message 'A failure throws with gh''s reason'
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
        Register-GitHubCredentialHelper -WhatIf
        Register-GitHubCredentialHelper -Hostname 'ghe.example' -Force -WhatIf
    }

    # Assert
    $operation = 'What if: Performing the operation "Configure git to use gh for credentials" on target'
    $expected = @(
        "$operation ""every host gh is logged in to""."
        "$operation ""ghe.example""."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names the host, or every host'
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
        Register-GitHubCredentialHelper -Hostname 'https://ghe.example' -WhatIf
    } -MessageLike "*'https://ghe.example' is not a host name:*" -Message 'With -WhatIf, a bad host is still refused'

    # Act
    Register-GitHubCredentialHelper -Hostname 'ghe.example' -Force -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'setup-git', '--hostname', 'ghe.example', '--force') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a call that names no host, which fits both parameter sets
$fake = New-FakeGitHubCli
try {
    # Act
    $default = (Get-Command -Name Register-GitHubCredentialHelper).DefaultParameterSet
    Register-GitHubCredentialHelper
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected 'EveryHost' -Actual $default -Message 'The default set is the one that names no host'
    Assert-Equal -Expected @('auth', 'setup-git') -Actual $call.Arguments `
        -Message 'so a call with no parameters configures every host gh is logged in to'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
