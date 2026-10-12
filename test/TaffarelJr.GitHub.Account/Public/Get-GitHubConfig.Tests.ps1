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
# Arrange - one setting by name
$fake = New-FakeGitHubCli -Output @('ssh')
try {
    # Act
    $value = Get-GitHubConfig -Name 'git_protocol' -Hostname 'github.com'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'get', '--host', 'github.com', '--', 'git_protocol') -Actual $call.Arguments `
        -Message '-Name asks gh for that one setting, after the -- so it cannot be read as a flag'
    Assert-Equal -Expected 'ssh' -Actual $value -Message 'The value is returned as a string'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every setting, parsed from key=value lines
$fake = New-FakeGitHubCli -Output @('git_protocol=https', 'editor=', 'pager=less')
try {
    # Act
    $settings = Get-GitHubConfig
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'list') -Actual $call.Arguments -Message 'Without -Name, every setting is listed'
    Assert-Equal -Expected 3 -Actual $settings.Count `
        -Message 'Every key=value line becomes one object, including a blank value'
    Assert-Equal -Expected 'git_protocol' -Actual $settings[0].Name -Message 'The key before = becomes Name'
    Assert-Equal -Expected 'https' -Actual $settings[0].Value -Message 'The text after = becomes Value'
    Assert-Equal -Expected '' -Actual $settings[1].Value `
        -Message 'A blank value is kept as an empty string, not dropped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the settings of one host, one of them holding an = of its own
$fake = New-FakeGitHubCli -Output @('browser=open -a "Some App" --args a=b')
try {
    # Act
    $perHost = Get-GitHubConfig -Hostname 'ghe.example'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'list', '--host', 'ghe.example') -Actual $call.Arguments `
        -Message '-Hostname lists that host''s settings'
    Assert-Equal -Expected 'open -a "Some App" --args a=b' -Actual $perHost.Value `
        -Message 'Only the first = splits the line, so a value may hold one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a setting that has no value, for which gh prints nothing at all
$fake = New-FakeGitHubCli -Output @()
try {
    # Act
    $empty = Get-GitHubConfig -Name 'editor'

    # Assert
    Assert-Equal -Expected '' -Actual $empty -Message 'A setting gh prints nothing for comes back as an empty string'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a setting printed as an empty line
$fake = New-FakeGitHubCli -Output @('')
try {
    # Act
    $empty = Get-GitHubConfig -Name 'editor'

    # Assert
    Assert-Equal -Expected '' -Actual $empty -Message 'An empty line comes back as an empty string too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the stored token, which gh hands out as a "setting" of a host
$fake = New-FakeGitHubCli -Output @('gho_should_not_be_read')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubConfig -Name 'oauth_token' -Hostname 'github.com'
    } -MessageLike "-Name 'oauth_token' is not read here: 'oauth_token' is the stored token*Get-GitHubToken*." `
        -Message 'oauth_token is refused, pointing at the function that reads a token'
    Assert-Throws -ScriptBlock {
        Get-GitHubConfig -Name 'OAuth_Token'
    } -MessageLike "*'OAuth_Token' is the stored token*" -Message 'in any casing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never asked for it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name given but empty, as a lookup that came back with nothing would give it
$fake = New-FakeGitHubCli -Output @('editor=vim')
try {
    # Act / Assert
    foreach ($blank in '', ' ', $null) {
        Assert-Throws -ScriptBlock {
            Get-GitHubConfig -Name $blank
        } -MessageLike "*'$blank' is not a setting name: give one such as editor*leave -Name out*." `
            -Message "A name of '$blank' is refused, not read as 'list every setting'"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name gh does not know
$fake = New-FakeGitHubCli -ErrorOutput @('could not find key "nosuchkey"') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubConfig -Name 'nosuchkey'
    } -MessageLike '*Reading config nosuchkey failed*could not find key "nosuchkey"*' `
        -Message 'An unknown name throws, with gh''s own message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name that starts with a dash
$fake = New-FakeGitHubCli -Output @('value')
try {
    # Act
    $null = Get-GitHubConfig -Name '-h'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'get', '--', '-h') -Actual $call.Arguments `
        -Message 'A name starting with a dash goes after the --, where gh reads it as a name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
