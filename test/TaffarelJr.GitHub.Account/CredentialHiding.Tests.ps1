#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the tables hand to Assert-Throws, by scope.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'A test builds a fake secret from a literal.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$url = 'https://user:SENTINEL@ghe.example.com/o/r'
$shown = 'https://***@ghe.example.com/o/r'
$escape = { param([string]$Text) [WildcardPattern]::Escape($Text) }
$settings = @('git_protocol=https', 'editor=', 'pager=')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every function that takes -Hostname, given a host that carries a credential
$hostMessage = "Cannot validate argument on parameter 'Hostname'. '***@ghe.example.com' is not a host name: give it" +
' bare, such as github.com - labels of letters, digits, dashes, and underscores joined by single dots, none starting' +
' or ending with a dash, and no scheme, port, path, space, or trailing dot - or leave -Hostname out for the default' +
' host.'
$hostCases = @(
    @{ Command = 'Connect-GitHubAccount'; Arguments = @{ Token = 't' } }
    @{ Command = 'Disconnect-GitHubAccount'; Arguments = @{} }
    @{ Command = 'Get-GitHubAuthStatus'; Arguments = @{} }
    @{ Command = 'Get-GitHubConfig'; Arguments = @{} }
    @{ Command = 'Get-GitHubOrganization'; Arguments = @{} }
    @{ Command = 'Get-GitHubToken'; Arguments = @{} }
    @{ Command = 'Register-GitHubCredentialHelper'; Arguments = @{} }
    @{ Command = 'Set-GitHubConfig'; Arguments = @{ Name = 'editor'; Value = 'vim' } }
    @{ Command = 'Switch-GitHubAccount'; Arguments = @{} }
)
$fake = New-FakeGitHubCli -Output @('[]')
try {
    foreach ($case in $hostCases) {
        # Act / Assert
        $arguments = $case.Arguments
        Assert-Throws -ScriptBlock {
            & $case.Command @arguments -Hostname 'user:SENTINEL@ghe.example.com'
        } -MessageLike (& $escape $hostMessage) -Message "$($case.Command) shows a -Hostname with a credential hidden"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every function that takes -User, given an account that carries a credential
$userTail = 'is not an account name: give the login alone, such as octocat, with no space, slash, colon, @, ?, #, *,' +
' or leading dash - or leave -User out for the active account.'
$userCases = @(
    @{
        Command  = 'Disconnect-GitHubAccount'
        Given    = 'user:SENTINEL@h.example'
        Expected = "Cannot validate argument on parameter 'User'. '***@h.example' $userTail"
    }
    @{
        Command  = 'Get-GitHubToken'
        Given    = $url
        Expected = "Cannot validate argument on parameter 'User'. '$shown' $userTail"
    }
    @{
        Command  = 'Switch-GitHubAccount'
        Given    = 'user:SENTINEL@h.example'
        Expected = "Cannot validate argument on parameter 'User'. '***@h.example' $userTail"
    }
)
$fake = New-FakeGitHubCli -Output @('gho_fake')
try {
    foreach ($case in $userCases) {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $case.Command -User $case.Given
        } -MessageLike (& $escape $case.Expected) -Message "$($case.Command) shows a -User with a credential hidden"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a setting name that carries a credential, against the settings gh lists
$fake = New-FakeGitHubCli -Output $settings
$settingCases = @(
    @{
        Block    = { Set-GitHubConfig -Name 'user:SENTINEL@h.example' -Value 'x' }
        Expected = "-Name '***@h.example' is not a setting gh has: give one of git_protocol, editor, pager."
        Name     = 'Set-GitHubConfig shows a -Name gh does not list without its credential'
    }
    @{
        Block    = { Set-GitHubConfig -Name 'user:SENTINEL@h.example' -Value "a`nb" }
        Expected = "-Value for '***@h.example' holds a line break, but a gh setting is one line:" +
        ' give the value on one line.'
        Name     = 'and a -Name beside a value with a line break'
    }
)
try {
    # Act / Assert
    foreach ($case in $settingCases) {
        Assert-Throws -ScriptBlock $case.Block -MessageLike (& $escape $case.Expected) -Message $case.Name
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that cannot list its settings, echoing a URL
$fake = New-FakeGitHubCli -Output @("moved $url") -ErrorOutput @("Get `"$url`": HTTP 404") -ExitCode 1
try {
    $expected = "Setting config ***@h.example failed: could not read gh's settings to check the name." +
    " Listing config failed: gh config list (exit 1)`nmoved $shown`nGet `"$shown`": HTTP 404"

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubConfig -Name 'user:SENTINEL@h.example' -Value 'x' } `
        -MessageLike (& $escape $expected) `
        -Message 'Set-GitHubConfig shows no credential in the name, or in the reason the listing failed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that lists its settings and then fails to set one to a URL with a credential
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = $settings }
    @{ ErrorOutput = @("Get `"$url`": HTTP 404"); ExitCode = 1 }
)
try {
    $expected = "Setting config editor failed: gh config set -- editor *** (exit 1)`nGet `"***`": HTTP 404"

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubConfig -Name 'editor' -Value $url } -MessageLike (& $escape $expected) `
        -Message 'and none in the value it was setting, which is hidden whole, or in what gh printed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing the URL on stdout and stderr
$fake = New-FakeGitHubCli -Output @("moved $url") -ErrorOutput @("Get `"$url`": HTTP 404") -ExitCode 1
$printed = "`nmoved $shown`nGet `"$shown`": HTTP 404"
$secure = ConvertTo-SecureString -String 'ghp_SENTINEL_TOKEN' -AsPlainText -Force
$failures = @(
    @{
        Block    = {
            Connect-GitHubAccount -Token 'ghp_SENTINEL_TOKEN' -Hostname 'ghe.example.com' -GitProtocol https `
                -InsecureStorage
        }
        Expected = 'Logging in failed: gh auth login --with-token --hostname ghe.example.com --git-protocol https' +
        " --insecure-storage (exit 1)$printed"
        Name     = 'Connect-GitHubAccount shows no token, and no credential in what gh printed'
    }
    @{
        Block    = { Connect-GitHubAccount -SecureToken $secure }
        Expected = "Logging in failed: gh auth login --with-token (exit 1)$printed"
        Name     = 'and none for a SecureString token'
    }
    @{
        Block    = { Disconnect-GitHubAccount -User 'octocat' -Hostname 'ghe.example.com' }
        Expected = "Logging out failed: gh auth logout --user octocat --hostname ghe.example.com (exit 1)$printed"
        Name     = 'Disconnect-GitHubAccount shows no credential in what gh printed'
    }
    @{
        Block    = { Switch-GitHubAccount -User 'octocat' -Hostname 'ghe.example.com' }
        Expected = "Switching the active account failed: gh auth switch --user octocat --hostname ghe.example.com" +
        " (exit 1)$printed"
        Name     = 'Switch-GitHubAccount shows no credential in what gh printed'
    }
    @{
        Block    = { Register-GitHubCredentialHelper -Hostname 'ghe.example.com' -Force }
        Expected = 'Configuring git to use gh for credentials failed: gh auth setup-git --hostname ghe.example.com' +
        " --force (exit 1)$printed"
        Name     = 'Register-GitHubCredentialHelper shows no credential in what gh printed'
    }
    @{
        Block    = { Clear-GitHubConfigCache }
        Expected = "Clearing gh's cache failed: gh config clear-cache (exit 1)$printed"
        Name     = 'Clear-GitHubConfigCache shows no credential in what gh printed'
    }
    @{
        Block    = { Get-GitHubAuthStatus -Hostname 'ghe.example.com' -Active -ShowToken }
        Expected = "Reading authentication status failed: gh auth status --json hosts --jq '.hosts | add // []'" +
        " --hostname ghe.example.com --active --show-token (exit 1)$printed"
        Name     = 'Get-GitHubAuthStatus shows no credential in what gh printed'
    }
    @{
        Block    = { Get-GitHubOrganization -Hostname 'ghe.example.com' }
        Expected = 'Calling user/orgs?per_page=100 failed: gh api user/orgs?per_page=100 --paginate --slurp' +
        " --hostname ghe.example.com (exit 1)$printed"
        Name     = 'Get-GitHubOrganization shows no credential in what gh printed'
    }
    @{
        Block    = { Get-GitHubToken -User 'octocat' -Hostname 'ghe.example.com' }
        Expected = "Reading the authentication token failed: gh auth token --hostname ghe.example.com --user octocat" +
        " (exit 1)$printed"
        Name     = 'Get-GitHubToken shows no credential in what gh printed'
    }
    @{
        Block    = { Get-GitHubConfig -Name $url -Hostname 'ghe.example.com' }
        Expected = "Reading config $shown failed: gh config get --host ghe.example.com -- $shown (exit 1)$printed"
        Name     = 'Get-GitHubConfig shows no credential in the name it read or in what gh printed'
    }
    @{
        Block    = { Get-GitHubConfig -Hostname 'ghe.example.com' }
        Expected = "Listing config failed: gh config list --host ghe.example.com (exit 1)$printed"
        Name     = 'and none in the list'
    }
)
try {
    # Act / Assert
    foreach ($case in $failures) {
        Assert-Throws -ScriptBlock $case.Block -MessageLike (& $escape $case.Expected) -Message $case.Name
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that answers with text that is not JSON
$fake = New-FakeGitHubCli -Output @("moved $url")
$start = "gh's output is not valid JSON, starting 'moved $shown': 'm' is an invalid start of a value." +
' LineNumber: 0 | BytePositionInLine: 0.'
$unreadable = @(
    @{
        Block    = { Get-GitHubAuthStatus }
        Expected = $start
        Name     = 'Get-GitHubAuthStatus shows no credential in an answer it cannot read'
    }
    @{
        Block    = { Get-GitHubOrganization }
        Expected = "The response from user/orgs?per_page=100 is not JSON - give -Raw to read it as text. $start"
        Name     = 'Get-GitHubOrganization shows none'
    }
)
try {
    # Act / Assert
    foreach ($case in $unreadable) {
        Assert-Throws -ScriptBlock $case.Block -MessageLike (& $escape $case.Expected) -Message $case.Name
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
