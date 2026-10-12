#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server: which application's store a
# delete reaches is decided by gh's --app, so the store is proved here, which
# the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$routes = [ordered]@{
    '/repos/o/r/actions/secrets/A'    = @{ Status = 204; Body = '' }
    '/repos/o/r/dependabot/secrets/A' = @{ Status = 204; Body = '' }
}
$listed = [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a listed Actions secret piped with its own application named again
    $listed | Remove-GitHubSecret -Application 'actions'
    $requests = @(Get-FakeGitHubRequest -Server $server)

    # Assert
    Assert-Equal -Expected @('DELETE /repos/o/r/actions/secrets/A') `
        -Actual @($requests.ForEach({ "$($_.Method) $($_.Path)" })) `
        -Message 'gh deletes the secret from the Actions store it was listed from'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - the same secret with another application named
    Assert-Throws -ScriptBlock {
        $listed | Remove-GitHubSecret -Application 'dependabot'
    } -MessageLike 'Secret A is in the actions store, but -Application names dependabot: give one or the other.' `
        -Message 'Another application is refused, so the Dependabot namesake is not deleted'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubRequest -Server $server).Count `
        -Message 'and gh sends no request for it'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
