#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real GitHub REST API; the authenticated account may belong to
# zero organizations, so only the call's own shape is asserted
$orgs = @(Get-GitHubOrganization)

# Assert
$withoutLogin = @($orgs | Where-Object { [string]::IsNullOrEmpty($_.Login) })
$withoutId = @($orgs | Where-Object { $_.Id -le 0 })
Assert-Equal -Expected 0 -Actual $withoutLogin.Count -Message 'Every organization returned carries its login'
Assert-Equal -Expected 0 -Actual $withoutId.Count -Message 'and its numeric id'

exit (Complete-TestRun)
