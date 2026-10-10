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
# Act - the real gh against a public repository, so a --json field name that
# does not exist fails here rather than at a caller
$repository = Get-GitHubRepository -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 'cli/cli' -Actual $repository.NameWithOwner -Message 'The live repository is described'
Assert-That -Condition (-not [string]::IsNullOrEmpty($repository.DefaultBranchRef.Name)) -Message 'A nested field gh really returns is populated'
Assert-That -Condition ($repository.PSObject.Properties.Name -contains 'IsArchived') -Message 'A requested field is present as a PascalCase property'

#───────────────────────────────────────────────────────────────────────────────
# Act - a short listing
$repositories = Get-GitHubRepository -List -Owner 'cli' -Limit 2

# Assert
Assert-Equal -Expected 2 -Actual $repositories.Count -Message 'The live listing honors -Limit'
Assert-That -Condition (-not [string]::IsNullOrEmpty($repositories[0].Url)) -Message 'A listed repository carries its URL'

exit (Complete-TestRun)
