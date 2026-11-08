#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a real REST read
$repository = Invoke-GitHubApi -Endpoint 'repos/cli/cli'

# Assert
Assert-Equal -Expected 'cli/cli' -Actual $repository.full_name `
    -Message "A REST response keeps GitHub's own snake_case field names"
Assert-That -Condition (-not [string]::IsNullOrEmpty($repository.default_branch)) -Message 'A REST field is populated'

#───────────────────────────────────────────────────────────────────────────────
# Act - a jq projection
$name = Invoke-GitHubApi -Endpoint 'repos/cli/cli' -Jq '.name'

# Assert
Assert-Equal -Expected 'cli' -Actual $name -Message 'A jq result comes back as text lines'

#───────────────────────────────────────────────────────────────────────────────
# Act - a paginated list, three items to a page
$repositories = @(Invoke-GitHubApi -Endpoint 'users/octocat/repos?per_page=3' -Paginate)

# Assert
Assert-That -Condition ($repositories.Count -gt 3) `
    -Message "-Paginate joins every page, so there are more items than one page holds (got $($repositories.Count))"
Assert-That -Condition (@($repositories | Where-Object { $_ -is [array] }).Count -eq 0) `
    -Message 'and the pages are flattened into items, not returned as lists'
Assert-Equal -Expected 'octocat' -Actual $repositories[0].owner.login -Message 'Each item is a parsed REST object'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - probes that succeed and fail
Assert-Equal -Expected $true -Actual (Test-GitHubApi -Endpoint 'repos/cli/cli') `
    -Message 'A probe of a real endpoint reports $true'
Assert-Equal -Expected $false -Actual (Test-GitHubApi -Endpoint 'repos/cli/this-repository-does-not-exist') `
    -Message 'A probe of a missing endpoint reports $false without throwing'

exit (Complete-TestRun)
