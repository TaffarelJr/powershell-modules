#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server: the words gh fails with, which
# the message carries, and which the fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$routes = [ordered]@{
    '/repos/o/r/actions/runs/1?*' = @{ Status = 404; Body = '{"message":"Not Found"}' }
    '/repos/o/r/actions/runs/2?*' = @{ Status = 401; Body = '{"message":"Bad credentials"}' }
    '/repos/o/r/actions/runs/3?*' = @{ Status = 403; Body = '{"message":"Resource not accessible by integration"}' }
    '/repos/o/r/actions/runs/4?*' = @{ Status = 429; Body = '{"message":"Too Many Requests"}' }
    '/repos/o/r/actions/runs/5?*' = @{ Status = 500; Body = '{"message":"Server Error"}' }
}

$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a run GitHub does not know, a token it refuses, a token that
    # may not see the run, a rate limit, and a server error
    $cases = @(
        @{ RunId = 1; Status = 404; Reason = '*HTTP 404: Not Found*' }
        @{ RunId = 2; Status = 401; Reason = '*HTTP 401: Bad credentials*' }
        @{ RunId = 3; Status = 403; Reason = '*HTTP 403: Resource not accessible by integration*' }
        @{ RunId = 4; Status = 429; Reason = '*HTTP 429: Too Many Requests*' }
        @{ RunId = 5; Status = 500; Reason = '*HTTP 500: Server Error*' }
    )
    foreach ($case in $cases) {
        $runId = $case.RunId
        $before = @(Get-FakeGitHubRequest -Server $server).Count

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Wait-GitHubWorkflowRun -RunId $runId -TimeoutSeconds 600 -PollSeconds 30 -Repository 'o/r'
        } -MessageLike "Could not read workflow run $runId (HTTP $($case.Status)):`n$($case.Reason)" `
            -Message "The answer the real gh reports ($($case.Reason)) throws at once, with its words"
        Assert-Equal -Expected 1 -Actual (@(Get-FakeGitHubRequest -Server $server).Count - $before) `
            -Message 'after one request'
    }
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
