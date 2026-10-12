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
# Act - the local login itself, read from the real gh
$accounts = @(Get-GitHubAuthStatus -Active)

# Assert
Assert-That -Condition ($accounts.Count -gt 0) -Message 'The active login is reported'
Assert-That -Condition (-not [string]::IsNullOrEmpty($accounts[0].Login)) `
    -Message 'The active login carries its user name'

exit (Complete-TestRun)
