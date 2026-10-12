#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, checking the loopback server's fake token: the shape of what
# gh reports per account is proved here, which the in-process fake gh cannot
# show. -Hostname keeps gh off github.com, which the fake token would also be
# tried against.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$scopes = @{ 'X-Oauth-Scopes' = 'gist, read:org, repo' }
$routes = [ordered]@{
    '/graphql' = @{ Body = '{"data":{"viewer":{"login":"octo"}}}'; Headers = $scopes }
    '/'        = @{ Body = '{}'; Headers = $scopes }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a token the server accepts
$server = Start-FakeGitHubServer -Route $routes
try {
    # Act
    $account = Get-GitHubAuthStatus -Hostname 'github.localhost' -ShowToken

    # Assert
    Assert-Equal -Expected 'octo' -Actual $account.Login -Message 'A working token is reported with its login'
    Assert-Equal -Expected 'success' -Actual $account.State -Message 'in the success state'
    Assert-Equal -Expected $null -Actual $account.Error -Message 'with an Error of $null, which gh leaves out'
    Assert-Equal -Expected ([string[]]@('gist', 'read:org', 'repo')) -Actual $account.Scopes `
        -Message 'its scopes, from gh''s comma-separated text, as an array'
    Assert-Equal -Expected 'fake-token-for-a-contract-test' -Actual $account.Token `
        -Message 'and with -ShowToken, the token'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a token the server refuses
$server = Start-FakeGitHubServer -Route ([ordered]@{ '*' = @{ Status = 401; Body = '{"message":"Bad credentials"}' } })
try {
    # Act
    $account = Get-GitHubAuthStatus -Hostname 'github.localhost'

    # Assert
    Assert-Equal -Expected 'error' -Actual $account.State -Message 'A refused token is reported in the error state'
    Assert-That -Condition ($account.Error -like '*401*') -Message 'with gh''s reason in Error'
    Assert-Equal -Expected ([string[]]@()) -Actual $account.Scopes -Message 'an empty Scopes, which gh leaves out'
    Assert-Equal -Expected $null -Actual $account.Token -Message 'and a Token of $null, not asked for'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
