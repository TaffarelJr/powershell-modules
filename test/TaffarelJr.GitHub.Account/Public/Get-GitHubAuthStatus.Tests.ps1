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
# Arrange - two accounts, already flattened by the jq gh is asked to apply
$json = '[{"host":"github.com","login":"me","active":true,"state":"success"},' +
'{"host":"github.com","login":"work","active":false,"state":"success"}]'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $accounts = @(Get-GitHubAuthStatus)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('auth', 'status', '--json', 'hosts', '--jq', '.hosts | add // []')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'gh is asked for JSON, flattened across hosts'
    Assert-Equal -Expected 2 -Actual $accounts.Count -Message 'Every account is returned'
    Assert-Equal -Expected 'me' -Actual $accounts[0].Login -Message 'Field names are PascalCase'
    Assert-Equal -Expected $true -Actual $accounts[0].Active -Message 'The active flag is carried over'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a narrowed query
$fake = New-FakeGitHubCli -Output @('[{"host":"ghe.example","login":"me","active":true}]')
try {
    # Act
    $accounts = Get-GitHubAuthStatus -Hostname 'ghe.example' -Active -ShowToken
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'auth', 'status', '--json', 'hosts', '--jq', '.hosts | add // []'
        '--hostname', 'ghe.example', '--active', '--show-token'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag'
    Assert-That -Condition ($accounts -isnot [array]) `
        -Message 'A single account is written as that one object, not wrapped in an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no accounts at all
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $accounts = @(Get-GitHubAuthStatus)

    # Assert
    Assert-Equal -Expected 0 -Actual $accounts.Count `
        -Message 'No accounts writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh with no login at all, which says so on stderr beside its empty answer
$reason = 'You are not logged into any GitHub hosts. To log in, run: gh auth login'
$fake = New-FakeGitHubCli -Output @('[]') -ErrorOutput @($reason)
try {
    # Act
    $loggedOut = @(Get-GitHubAuthStatus)

    # Assert
    Assert-Equal -Expected 0 -Actual $loggedOut.Count `
        -Message 'No login is no accounts, not a failure to read gh''s answer'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a GH_TOKEN that GitHub rejected, which gh lists as an account in the error state
$json = '[{"active":true,"error":"401 Unauthorized","gitProtocol":"https","host":"github.com",' +
'"login":"","state":"error","tokenSource":"GH_TOKEN"}]'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $broken = Get-GitHubAuthStatus -Active

    # Assert
    Assert-Equal -Expected 'error' -Actual $broken.State `
        -Message 'An account whose token was rejected is listed, in the error state'
    Assert-Equal -Expected '401 Unauthorized' -Actual $broken.Error -Message 'with the reason'
    Assert-Equal -Expected 'GH_TOKEN' -Actual $broken.TokenSource -Message 'and where the token came from'
    Assert-Equal -Expected '' -Actual $broken.Login -Message 'with no login to name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a working account and a broken one, each missing fields gh leaves out when empty
$working = '{"active":true,"gitProtocol":"https","host":"github.com","login":"me",' +
'"scopes":"gist, read:org, repo","state":"success","tokenSource":"keyring"}'
$broken = '{"active":false,"error":"401 Unauthorized","gitProtocol":"ssh","host":"github.com","login":"",' +
'"state":"error","tokenSource":"GH_TOKEN"}'
$fake = New-FakeGitHubCli -Output @("[$working,$broken]")
try {
    # Act
    $accounts = @(Get-GitHubAuthStatus)
    $failing = @($accounts | Where-Object { $_.Error })

    # Assert
    $shape = @('Host', 'Login', 'Active', 'State', 'Error', 'TokenSource', 'GitProtocol', 'Scopes', 'Token')
    Assert-Equal -Expected $shape -Actual @($accounts[0].PSObject.Properties.Name) `
        -Message 'A working account has every property'
    Assert-Equal -Expected $shape -Actual @($accounts[1].PSObject.Properties.Name) -Message 'and so does a broken one'
    Assert-Equal -Expected $null -Actual $accounts[0].Error -Message 'An Error gh left out is $null'
    Assert-Equal -Expected $null -Actual $accounts[0].Token -Message 'and so is a Token gh was not asked for'
    Assert-Equal -Expected ([string[]]@('gist', 'read:org', 'repo')) -Actual $accounts[0].Scopes `
        -Message 'Scopes are split into an array'
    Assert-That -Condition ($accounts[0].Scopes -is [string[]]) -Message 'as a [string[]]'
    Assert-Equal -Expected ([string[]]@()) -Actual $accounts[1].Scopes `
        -Message 'and are an empty array when gh reports none'
    Assert-That -Condition ($accounts[1].Scopes -is [string[]]) -Message 'still a [string[]]'
    Assert-Equal -Expected 1 -Actual $failing.Count `
        -Message 'so a strict-mode filter on Error picks out the broken account alone'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one scope, and the token asked for
$fake = New-FakeGitHubCli -Output @('[{"host":"github.com","login":"me","scopes":"repo","token":"gho_fake"}]')
try {
    # Act
    $account = Get-GitHubAuthStatus -ShowToken

    # Assert
    Assert-Equal -Expected ([string[]]@('repo')) -Actual $account.Scopes -Message 'A single scope is still an array'
    Assert-That -Condition ($account.Scopes -is [string[]]) -Message 'a [string[]]'
    Assert-Equal -Expected 'gho_fake' -Actual $account.Token -Message 'and the token gh printed is kept'
    Assert-Equal -Expected $null -Actual $account.State -Message 'A field gh did not print at all is $null too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a field this module does not name, as a later gh may add
$fake = New-FakeGitHubCli -Output @('[{"host":"github.com","login":"me","newField":1}]')
try {
    # Act
    $account = Get-GitHubAuthStatus

    # Assert
    $shape = @('Host', 'Login', 'Active', 'State', 'Error', 'TokenSource', 'GitProtocol', 'Scopes', 'Token', 'NewField')
    Assert-Equal -Expected $shape -Actual @($account.PSObject.Properties.Name) `
        -Message 'A field gh adds is kept, after the fixed ones'
    Assert-Equal -Expected 1L -Actual $account.NewField -Message 'with its value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a host given by position
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubAuthStatus 'ghe.example'
    } -MessageLike '*positional parameter cannot be found*' -Message 'The host is never positional'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh too old to know the --json flag
$fake = New-FakeGitHubCli -ErrorOutput @('unknown flag: --json') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubAuthStatus
    } -MessageLike '*Reading authentication status failed*unknown flag: --json*' `
        -Message 'An old gh fails with its own message about the flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
