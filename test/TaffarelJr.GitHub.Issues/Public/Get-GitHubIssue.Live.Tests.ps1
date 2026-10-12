#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh against a public repository, every state so there is
# always something to list. gh's issue fields are served over GraphQL and
# some (id, title) require the read:project scope on the token regardless
# of which fields are actually requested - a token without it is a valid,
# unrelated environment limitation, not a module defect, so that one case
# is skipped rather than failed.
try {
    $issues = Get-GitHubIssue -List -State all -Limit 2 -Repository 'cli/cli'
}
catch {
    if ($_.Exception.Message -like '*required scopes*') {
        Write-Host "skipped - the authenticated token lacks a scope gh's issue query needs"
        exit (Complete-TestRun)
    }

    throw
}

# Assert
Assert-Equal -Expected 2 -Actual $issues.Count -Message 'The live listing honors -Limit'
Assert-That -Condition ($issues[0].Number -gt 0) -Message 'A listed issue carries its number'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same issue on its own
$single = Get-GitHubIssue -Issue $issues[0].Number -Repository 'cli/cli'

# Assert
Assert-Equal -Expected $issues[0].Number -Actual $single.Number -Message 'An issue described by number is the one asked for'
Assert-That -Condition ($single.PSObject.Properties.Name -contains 'IsPinned') -Message 'A requested field is present as a PascalCase property'

exit (Complete-TestRun)
