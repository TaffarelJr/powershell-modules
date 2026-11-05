#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# What gh lists when asked for its settings; the fake answers every call with
# it, so the call that sets one is the second the fake sees.
$settings = @('git_protocol=https', 'editor=', 'pager=')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act
    Set-GitHubConfig -Name 'editor' -Value 'code --wait' -Hostname 'github.com'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('config', 'list') -Actual $calls[0].Arguments `
        -Message 'The name is checked against the settings gh lists first'
    $expected = @('config', 'set', '--host', 'github.com', '--', 'editor', 'code --wait')
    Assert-Equal -Expected $expected -Actual $calls[1].Arguments `
        -Message 'Name and value follow the -- and -Hostname becomes --host'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty value, which is legitimate for some settings
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act
    Set-GitHubConfig -Name 'editor' -Value ''
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('config', 'set', '--', 'editor', '') -Actual $calls[1].Arguments `
        -Message 'An empty value is accepted and passed through'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that starts with a dash
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act
    Set-GitHubConfig -Name 'editor' -Value '-nw'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('config', 'set', '--', 'editor', '-nw') -Actual $calls[1].Arguments `
        -Message 'A value starting with a dash goes after the --, where gh reads it as a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a misspelled name, which gh itself would store with only a warning
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubConfig -Name 'git_protocl' -Value 'ssh'
    } -MessageLike "-Name 'git_protocl' is not a setting gh has: give one of git_protocol, editor, pager*." `
        -Message 'A name gh does not list is refused, naming the settings it has'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and nothing is written'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubConfig -Name 'Editor' -Value 'vim'
    } -MessageLike "-Name 'Editor' is not a setting gh has*" -Message 'Names are case-sensitive'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value with a line break, which gh's key=value list would read back as two settings
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubConfig -Name 'editor' -Value "vim`nfoo=bar"
    } -MessageLike "-Value for 'editor' holds a line break*give the value on one line." `
        -Message 'A line feed in the value is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubConfig -Name 'editor' -Value "vim`r"
    } -MessageLike "-Value for 'editor' holds a line break*" -Message 'and so is a carriage return'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'with gh never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh's settings cannot be listed to check the name against
$fake = New-FakeGitHubCli -ErrorOutput @('boom') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubConfig -Name 'editor' -Value 'vim'
    } -MessageLike "Setting config editor failed: could not read gh's settings*Listing config failed*boom*" `
        -Message 'The failure is reported as the setting''s, with the listing''s own reason after it'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and nothing is written'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubConfig -Name 'editor' -Value 'VALUE_SENTINEL --wait' -Hostname 'github.com' -WhatIf
        Set-GitHubConfig -Name 'pager' -Value 'VALUE_SENTINEL' -WhatIf
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    $expected = @(
        'What if: Performing the operation "Set gh setting" on target "editor on github.com".'
        'What if: Performing the operation "Set gh setting" on target "pager".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the setting and the host it is set for, if any'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never the value'
    Assert-Equal -Expected @('config list', 'config list') -Actual @($calls.ForEach({ $_.Arguments -join ' ' })) `
        -Message 'gh is called only to read the settings, which checks the name; nothing is set'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubConfig -Name 'editr' -Value 'vim' -WhatIf
    } -MessageLike "-Name 'editr' is not a setting gh has: give one of git_protocol, editor, pager." `
        -Message 'With -WhatIf, a name gh does not list is still refused'

    # Act
    Set-GitHubConfig -Name 'editor' -Value 'vim' -Hostname 'github.com' -Confirm:$false
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('config', 'set', '--host', 'github.com', '--', 'editor', 'vim') `
        -Actual $calls[-1].Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
