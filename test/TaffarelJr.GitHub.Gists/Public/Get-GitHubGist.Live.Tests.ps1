#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

# The fields and file names asserted below belong to a gist that exists, so a
# login with none has nothing to check them against. GitHub answers 403 to
# the gists endpoint for an enterprise-managed login (worded "Rate Limit
# Exceeded" although most of the limit is left), so that login has none either.
$gists = @()
try {
    $gists = @(Get-GitHubGist -List)
}
catch [System.InvalidOperationException] {
    if ($_.Exception.Message -notmatch 'HTTP 403') {
        throw
    }

    exit (Skip-TestRun -Reason 'GitHub refuses gist access to this login (HTTP 403)')
}

if ($gists.Count -eq 0) {
    exit (Skip-TestRun -Reason 'the account has no gists')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the first listed gist
$listed = $gists[0]
$listedFields = $listed.PSObject.Properties.Name

# Assert
Assert-That -Condition ($listedFields -contains 'Id') -Message 'A listed gist has an Id'
Assert-That -Condition ($listedFields -contains 'HtmlUrl') `
    -Message 'and the HtmlUrl its page lives at, re-cased from html_url'
Assert-That -Condition ($listedFields -contains 'Files') -Message 'and its Files'

#───────────────────────────────────────────────────────────────────────────────
# Act - that gist in full, by id
$gist = Get-GitHubGist -Id $listed.Id
$firstFile = @($gist.Files.PSBase.Values)[0]

# Assert
Assert-Equal -Expected $listed.Id -Actual $gist.Id -Message 'A gist described by id is the one asked for'
Assert-Equal -Expected @($listed.Files.PSBase.Keys) -Actual @($gist.Files.PSBase.Keys) `
    -Message 'with the same real file names the listing gave, whatever characters they hold'
Assert-That -Condition ($firstFile.PSObject.Properties.Name -contains 'Content') `
    -Message 'and each file carries its Content'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same gist, by the URL its page lives at
$byUrl = Get-GitHubGist -Id $listed.HtmlUrl

# Assert
Assert-Equal -Expected $listed.Id -Actual $byUrl.Id `
    -Message 'The URL GitHub itself gives for a gist is understood as that gist'

exit (Complete-TestRun)
