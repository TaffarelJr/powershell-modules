#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server: what gh prints for a dispatch,
# and the request it sends, which the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$ci = '{"id":11,"name":"CI","path":".github/workflows/ci.yml","state":"active"}'
$old = '{"id":12,"name":"Old","path":".github/workflows/old.yml","state":"active"}'
$details = '{"workflow_run_id":905,"run_url":"http://api.github.localhost/repos/o/r/actions/runs/905",' +
'"html_url":"http://github.localhost/o/r/actions/runs/905"}'
$routes = [ordered]@{
    '/repos/o/r/actions/workflows/ci.yml'        = @{ Body = $ci }
    '/repos/o/r/actions/workflows/11/dispatches' = @{ Status = 200; Body = $details }
    '/repos/o/r/actions/workflows/old.yml'       = @{ Body = $old }
    '/repos/o/r/actions/workflows/12/dispatches' = @{ Status = 204; Body = '' }
}

$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a dispatch GitHub answers with the new run
    $inputs = @{ dry_run = [switch]::new($true) }
    $dispatch = Start-GitHubWorkflow -Workflow 'ci.yml' -Ref 'main' -Inputs $inputs -Repository 'o/r'
    $request = @(Get-FakeGitHubRequest -Server $server)[-1]

    # Assert
    $expected = [PSCustomObject]@{
        Url        = 'http://github.localhost/o/r/actions/runs/905'
        DatabaseId = [long]905
    }
    Assert-Equal -Expected $expected -Actual $dispatch -Message 'The run gh prints is returned, with its id'
    Assert-Equal -Expected 'POST /repos/o/r/actions/workflows/11/dispatches' `
        -Actual "$($request.Method) $($request.Path)" `
        -Message 'gh dispatches the workflow it looked up'
    Assert-Equal -Expected '{"inputs":{"dry_run":"true"},"ref":"main","return_run_details":true}' `
        -Actual $request.Text `
        -Message 'with a switch input as true, and asking for the run'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a dispatch GitHub answers with no run, as an older GitHub does
    $dispatch = Start-GitHubWorkflow -Workflow 'old.yml' -Ref 'main' -Repository 'o/r'

    # Assert
    Assert-Equal -Expected ([PSCustomObject]@{ Url = $null; DatabaseId = $null }) -Actual $dispatch `
        -Message 'No run in the answer gives an object with neither a Url nor a DatabaseId'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
