#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server: the listing request gh builds
# from the flags, and the words gh fails with, which the fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$ci = '{"id":11,"name":"CI","path":".github/workflows/ci.yml","state":"active"}'
$runs = '{"total_count":2,"workflow_runs":[' +
'{"id":905,"event":"workflow_dispatch"},{"id":901,"event":"workflow_dispatch"}]}'
$routes = [ordered]@{
    '/repos/o/r/actions/workflows/ci.yml'     = @{ Body = $ci }
    '/repos/o/r/actions/workflows/11/runs?*'  = @{ Body = $runs }
    '/repos/o/r/actions/workflows/hidden.yml' = @{
        Status = 403
        Body   = '{"message":"Resource not accessible by integration"}'
    }
    '/repos/o/r/actions/workflows/broken.yml' = @{ Status = 500; Body = '{"message":"Server Error"}' }
}

$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @(901) -Ref 'release/1.0' -Repository 'o/r'
    $request = @(Get-FakeGitHubRequest -Server $server)[-1]

    # Assert
    Assert-Equal -Expected ([long]905) -Actual $id -Message 'The new run gh lists is returned'
    $query = '/repos/o/r/actions/workflows/11/runs' +
    '?branch=release%2F1.0&event=workflow_dispatch&exclude_pull_requests=true&per_page=20'
    Assert-Equal -Expected $query -Actual $request.Path `
        -Message 'gh lists only the workflow''s dispatched runs on the ref''s branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a workflow GitHub does not know, one the token may not see,
    # and a server error
    $cases = @(
        @{ Workflow = 'nope.yml'; Code = 'HTTP 404'; Reason = '*HTTP 404: workflow nope.yml not found*' }
        @{ Workflow = 'hidden.yml'; Code = 'HTTP 403'; Reason = '*HTTP 403: Resource not accessible by integration*' }
        @{ Workflow = 'broken.yml'; Code = 'HTTP 500'; Reason = '*HTTP 500: Server Error*' }
    )
    foreach ($case in $cases) {
        $workflow = $case.Workflow
        $before = @(Get-FakeGitHubRequest -Server $server).Count

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Wait-GitHubWorkflowRunStart -Workflow $workflow -Before @() -PollSeconds 30 -Repository 'o/r'
        } -MessageLike "Could not list the workflow_dispatch runs of '$workflow' ($($case.Code)):`n$($case.Reason)" `
            -Message "The answer the real gh reports ($($case.Reason)) throws at once, with its words"
        Assert-Equal -Expected 1 -Actual (@(Get-FakeGitHubRequest -Server $server).Count - $before) `
            -Message "after one request ($workflow)"
    }
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
