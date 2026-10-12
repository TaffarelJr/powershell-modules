#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a real search against GitHub, narrowed to one well-known owner
$repos = @(Find-GitHubRepository -Owner @('cli') -Limit 3)

# Assert
Assert-Equal -Expected 3 -Actual $repos.Count -Message 'The live search honors -Limit'
Assert-That -Condition (@($repos | ForEach-Object FullName | Where-Object { $_ -like 'cli/*' }).Count -eq 3) `
    -Message 'Each result carries its full name, in the owner asked for'
Assert-That -Condition (@($repos | ForEach-Object { $_.PSObject.Properties.Name }) -contains 'StargazersCount') `
    -Message 'A requested field is present as a PascalCase property'

#───────────────────────────────────────────────────────────────────────────────
# Act - that owner's repositories split by archived state
$current = @(Find-GitHubRepository -Owner @('cli') -Archived:$false -Limit 200)
$archived = @(Find-GitHubRepository -Owner @('cli') -Archived -Limit 200)

# Assert
Assert-That -Condition ($current.Count -gt 0) `
    -Message '-Archived:$false finds the owner''s repositories that are not archived'
Assert-Equal -Expected 0 -Actual @($current | Where-Object IsArchived).Count `
    -Message 'and none that is archived, so the false form reaches gh as a filter and not as a keyword'
Assert-Equal -Expected 0 -Actual @($archived | Where-Object { -not $_.IsArchived }).Count `
    -Message 'while -Archived finds only archived ones'

#───────────────────────────────────────────────────────────────────────────────
# Act - a sort given in another case than gh's
$byStars = @(Find-GitHubRepository -Owner @('cli') -Sort Stars -Order Asc -Limit 200)
$stars = @($byStars | ForEach-Object StargazersCount)
$sorted = @($stars | Sort-Object)

# Assert
Assert-That -Condition ($stars.Count -gt 1) -Message 'The owner has repositories to sort'
Assert-Equal -Expected $sorted -Actual $stars -Message 'GitHub honors the sort, as it reaches gh in lower case'

#───────────────────────────────────────────────────────────────────────────────
# Act - the owner's repositories in Go, and the same owner excluding Go with a dash-led query
$goOnly = @(Find-GitHubRepository -Owner @('cli') -Language Go -Limit 200)
$withoutGo = @(Find-GitHubRepository -Owner @('cli') -Query '-language:go' -Limit 200)

# Assert
Assert-That -Condition ($goOnly.Count -gt 0) `
    -Message 'The owner has Go repositories, among them cli/cli, the baseline the next check needs'
Assert-Equal -Expected 0 -Actual @($withoutGo | Where-Object Language -EQ 'Go').Count `
    -Message 'and a query starting with a dash excludes them, as the -- keeps gh from reading it as an option'

exit (Complete-TestRun)
