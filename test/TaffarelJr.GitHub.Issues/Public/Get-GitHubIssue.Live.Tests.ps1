#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh against a public repository, every state so there is
# always something to list, with the default fields: they must work for a
# token with no more than the usual scopes
$issues = @(Get-GitHubIssue -List -State all -Limit 2 -Repository 'cli/cli')

# Assert
Assert-Equal -Expected 2 -Actual $issues.Count -Message 'The live listing honors -Limit'
Assert-That -Condition ($issues[0].Number -gt 0) -Message 'A listed issue carries its number'
Assert-That -Condition ($issues[0].PSObject.Properties.Name -contains 'IssueType') `
    -Message 'and the newer fields the default asks for, so gh is new enough'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same issue on its own, and read through the object the listing gave
$single = Get-GitHubIssue -Issue $issues[0].Number -Repository 'cli/cli'
$byObject = $issues[0] | Get-GitHubIssue

# Assert
Assert-Equal -Expected $issues[0].Number -Actual $single.Number `
    -Message 'An issue described by number is the one asked for'
Assert-That -Condition ($single.PSObject.Properties.Name -contains 'IsPinned') `
    -Message 'A requested field is present as a PascalCase property'
Assert-Equal -Expected $issues[0].Number -Actual $byObject.Number `
    -Message 'A listed issue piped back in is found by its URL, with no -Repository'

#───────────────────────────────────────────────────────────────────────────────
# Act - the fields the default leaves out, asked for by name
$withComments = Get-GitHubIssue -Issue $issues[0].Number -Repository 'cli/cli' -Property 'number', 'comments'

# Assert
Assert-That -Condition ($withComments.PSObject.Properties.Name -contains 'Comments') `
    -Message '-Property can name comments, which the default leaves out'

#───────────────────────────────────────────────────────────────────────────────
# Act - the status of the authenticated user in that repository
$status = Get-GitHubIssueStatus -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 'Assigned, CreatedBy, Mentioned' `
    -Actual (($status.PSObject.Properties.Name | Sort-Object) -join ', ') `
    -Message 'The status groups are the three gh reports, with the default fields'

exit (Complete-TestRun)
