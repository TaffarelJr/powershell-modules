#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server: that gh accepts the argument
# vector for a named repository - which it refuses with any --remote flag -
# is proved here, which the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

# gh reports a fork created more than a minute ago as one that already
# existed, so the answer says it was created just now.
$created = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$fork = '{"node_id":"R_1","name":"r","created_at":"' + $created + '","owner":{"login":"me"}}'
$routes = [ordered]@{
    '/repos/o/r/forks' = @{ Status = 202; Body = $fork }
}

# Outside any git repository, so nothing of a clone is read or changed.
$outside = Join-Path ([IO.Path]::GetTempPath()) "fork-contract-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $outside | Out-Null
$server = Start-FakeGitHubServer -Route $routes
try {
    Push-Location -LiteralPath $outside

    #───────────────────────────────────────────────────────────────────────────
    # Act - a fork of a named repository
    $url = New-GitHubFork -Repository 'o/r'
    $request = @(Get-FakeGitHubRequest -Server $server)[-1]

    # Assert
    Assert-Equal -Expected 'POST /repos/o/r/forks' -Actual "$($request.Method) $($request.Path)" `
        -Message 'gh accepts the vector for a named repository and asks GitHub for the fork'
    Assert-Equal -Expected '{}' -Actual $request.Text.Trim() -Message 'with no options in the request'
    Assert-Equal -Expected 'http://github.localhost/me/r' -Actual $url `
        -Message 'and the URL gh prints for the new fork (plain HTTP on this test host) is returned'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same, into an organization under another name, default branch only
    New-GitHubFork -Repository 'o/r' -Organization 'org' -ForkName 'r' -DefaultBranchOnly | Out-Null
    $request = @(Get-FakeGitHubRequest -Server $server)[-1]
    $body = $request.Text | ConvertFrom-Json -AsHashtable

    # Assert
    Assert-Equal -Expected @{ organization = 'org'; name = 'r'; default_branch_only = $true } -Actual $body `
        -Message 'gh takes each option and sends it in the request'
}
finally {
    Pop-Location
    Stop-FakeGitHubServer -Server $server
    Remove-Item -LiteralPath $outside -Recurse -Force
}

exit (Complete-TestRun)
