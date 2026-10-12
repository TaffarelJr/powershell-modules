#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The real gh against the fake server: what the server's environment does to a
# gh that is asked for a real host.
$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a server that answers zen, and a call that names github.com
$server = Start-FakeGitHubServer -Route @{ '/zen' = @{ Body = '"local zen"' } }
try {
    # Act
    $local = Invoke-GitHubCommand -Activity 'Asking' -Argument @('api', 'zen')
    $real = Invoke-GitHubCommand -Activity 'Asking' -Argument @('api', '--hostname', 'github.com', 'zen') -Tolerant
    $requests = @(Get-FakeGitHubRequest -Server $server)

    # Assert
    Assert-Equal -Expected '"local zen"' -Actual $local -Message 'The default host is the fake server'
    Assert-Equal -Expected @($false, 1) -Actual @($real.Ok, $real.ExitCode) `
        -Message 'A call that names github.com fails'
    Assert-Equal -Expected 'Get "https://api.github.com/zen": Tunnel Refused By The Fake Server' -Actual $real.Message `
        -Message 'with the fake server''s refusal, not a response from GitHub'
    Assert-Equal -Expected @('GET /zen', 'CONNECT api.github.com:443') `
        -Actual @($requests.ForEach({ "$($_.Method) $($_.Path)" })) `
        -Message 'because the server is asked for the tunnel, records it, and refuses it'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
