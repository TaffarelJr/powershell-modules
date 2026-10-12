#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each changing function, called from a function that was given -WhatIf
$changes = @(
    @{ Call = { Add-GitHubReleaseAsset -Tag 'v1' -Path 'a.zip' -Repository 'o/r' }; Name = 'Add-GitHubReleaseAsset' }
    @{ Call = { New-GitHubRelease -Tag 'v1' -Repository 'o/r' }; Name = 'New-GitHubRelease' }
    @{ Call = { Remove-GitHubRelease -Tag 'v1' -Repository 'o/r' }; Name = 'Remove-GitHubRelease' }
    @{
        Call = { Remove-GitHubReleaseAsset -Tag 'v1' -Name 'a.zip' -Repository 'o/r' }
        Name = 'Remove-GitHubReleaseAsset'
    }
    @{
        Call = { Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.zip' -Repository 'o/r' }
        Name = 'Save-GitHubReleaseAsset'
    }
    @{ Call = { Set-GitHubRelease -Tag 'v1' -Draft:$false -Repository 'o/r' }; Name = 'Set-GitHubRelease' }
)
foreach ($change in $changes) {
    $fake = New-FakeGitHubCli
    try {
        # Act
        $call = $change.Call
        $result = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $call -WhatIf }

        # Assert
        Assert-Equal -Expected 1 -Actual $result.Messages.Count `
            -Message "$($change.Name) called from a function given -WhatIf says what it would do"
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
            -Message "and does not call gh"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
