#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a real REST read
$repository = Invoke-GitHubApi -Endpoint 'repos/cli/cli'

# Assert
Assert-Equal -Expected 'cli/cli' -Actual $repository.full_name -Message "A REST response keeps GitHub's own snake_case field names"
Assert-That -Condition (-not [string]::IsNullOrEmpty($repository.default_branch)) -Message 'A REST field is populated'

#───────────────────────────────────────────────────────────────────────────────
# Act - a jq projection
$name = Invoke-GitHubApi -Endpoint 'repos/cli/cli' -Jq '.name'

# Assert
Assert-Equal -Expected @('cli') -Actual $name -Message 'A jq result comes back as text lines'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - probes that succeed and fail
Assert-Equal -Expected $true -Actual (Test-GitHubApi -Endpoint 'repos/cli/cli') -Message 'A probe of a real endpoint reports $true'
Assert-Equal -Expected $false -Actual (Test-GitHubApi -Endpoint 'repos/cli/this-repository-does-not-exist') -Message 'A probe of a missing endpoint reports $false without throwing'

#───────────────────────────────────────────────────────────────────────────────
# Act - the local login itself
$accounts = Get-GitHubAuthStatus -Active

# Assert
Assert-That -Condition ($accounts.Count -gt 0) -Message 'The active login is reported'
Assert-That -Condition (-not [string]::IsNullOrEmpty($accounts[0].Login)) -Message 'The active login carries its user name'
Assert-That -Condition ((Get-GitHubToken).Length -gt 0) -Message 'The active token can be read'

exit (Complete-TestRun)
