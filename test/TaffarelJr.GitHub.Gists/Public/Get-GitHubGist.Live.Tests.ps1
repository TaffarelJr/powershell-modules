#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the authenticated user's own gists; the account may have none, so
# only the call's own shape is asserted when the list is empty
$gists = Get-GitHubGist -List -All

# Assert
Assert-That -Condition ($gists -is [array]) -Message 'The live call returns an array, with or without any gists'

if ($gists.Count -gt 0) {
    #───────────────────────────────────────────────────────────────────────
    # Act - the first gist in full
    $gist = Get-GitHubGist -Id $gists[0].Id

    # Assert
    Assert-Equal -Expected $gists[0].Id -Actual $gist.Id -Message 'A gist described by id is the one asked for'
    Assert-That -Condition ($gist.PSObject.Properties.Name -contains 'Files') -Message 'The full view carries the Files field'
}

exit (Complete-TestRun)
