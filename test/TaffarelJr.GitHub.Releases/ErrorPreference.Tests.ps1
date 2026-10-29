#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the tables hand to Get-WhatIfOutput, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a command inside the module that fails without throwing. A caller's -ErrorAction SilentlyContinue or
# Ignore would become the function's own preference and hide it, so the function sets its own to Stop.
& $module {
    Set-Item -LiteralPath 'Function:script:Format-GitHubReleaseTarget' -Value { Write-Error 'the target failed' }
}
$cases = @(
    @{
        Block = { Remove-GitHubRelease -Tag 'v1' -Repository 'o/r' -ErrorAction $preference }
        Name  = 'a failure in a process block, in a function that sets its preference in its begin block'
    }
    @{
        Block = { New-GitHubRelease -Tag 'v1' -Repository 'o/r' -ErrorAction $preference }
        Name  = 'a failure in a function with no named block'
    }
)
foreach ($case in $cases) {
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        $fake = New-FakeGitHubCli
        try {
            # Act
            $run = Get-WhatIfOutput -CaptureError -ScriptBlock $case.Block
            $calls = @(Get-FakeGitHubCall -Fixture $fake)

            # Assert
            $because = "$($case.Name), under -ErrorAction $preference"
            Assert-Equal -Expected 0 -Actual $calls.Count -Message "$because, goes on to no change"
            Assert-Equal -Expected 0 -Actual $run.Output.Count -Message "$because, returns nothing"
            Assert-That -Condition ($null -ne $run.Error) -Message "$because, raises a terminating error"
            Assert-Equal -Expected 'the target failed' -Actual $run.Error.Exception.Message `
                -Message "$because, raises the failure that was not thrown"
        }
        finally {
            Remove-FakeGitHubCli -Fixture $fake
        }
    }
}

exit (Complete-TestRun)
