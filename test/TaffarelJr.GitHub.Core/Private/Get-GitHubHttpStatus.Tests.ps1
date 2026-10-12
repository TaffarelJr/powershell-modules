#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Reads the status out of one message; the caller collects it as a list, so "none" is an empty one.
$read = {
    param([string]$Message)
    Get-GitHubHttpStatus -Message $Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the ways gh reports a status, and messages that report none
$cases = @(
    @{ Message = 'gh: Not Found (HTTP 404)'; Expected = @(404); Name = 'gh api''s (HTTP 404) is read' }
    @{ Message = 'gh: HTTP 401'; Expected = @(401); Name = 'and so is its bare gh: HTTP 401' }
    @{
        Message = 'HTTP 403: Resource not accessible by integration (https://api.github.com/repos/o/r)'
        Expected = @(403)
        Name = 'A line starting HTTP 403: is read'
    }
    @{
        Message = "warning: slow`nHTTP 502: Bad Gateway (https://api.github.com/x)"
        Expected = @(502)
        Name = 'on any line'
    }
    @{
        Message = "{`"message`":`"upstream HTTP 404`"}`ngh: Server Error (HTTP 500)"
        Expected = @(500)
        Name = 'gh api''s own (HTTP N) wins over a status inside the body'
    }
    @{
        Message = 'failed to get run: HTTP 404: Not Found (https://api.github.com/repos/o/r/actions/runs/9)'
        Expected = @(404)
        Name = 'A status after gh''s own words is read'
    }
    @{
        Message = 'could not list: failed to get run: HTTP 502: Bad Gateway'
        Expected = @(502)
        Name = 'however many of them come first'
    }
    @{ Message = 'note: HTTP 404 pages are common'; Expected = @(); Name = 'but words before it need the colon after it' }
    @{ Message = 'note: see HTTP 404: the page'; Expected = @(); Name = 'and running text between is not gh''s' }
    @{ Message = 'GraphQL: Could not resolve to a Repository'; Expected = @(); Name = 'A GraphQL error has none' }
    @{ Message = 'error connecting to api.github.com'; Expected = @(); Name = 'nor does a network failure' }
    @{ Message = 'HTTP 4040 is not a status'; Expected = @(); Name = 'A status is a whole three-digit number' }
    @{ Message = 'see the HTTP 404 page'; Expected = @(); Name = 'and one in running text is not gh''s' }
    @{ Message = ''; Expected = @(); Name = 'Nothing printed has none' }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual @(& $module $read $case.Message) -Message $case.Name
}

exit (Complete-TestRun)
