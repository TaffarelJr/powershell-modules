#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Stop-GitHubWorkflowRun -Id 123 -Force -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'cancel', '123', '--force', '--repo', 'o/r') -Actual $call.Arguments -Message 'The id is positional and -Force becomes --force'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - runs piped in by DatabaseId, as a listing returns them
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ DatabaseId = 1 }, [PSCustomObject]@{ DatabaseId = 2 }) | Stop-GitHubWorkflowRun
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped run is cancelled in its own call'
    Assert-Equal -Expected @('run', 'cancel', '2') -Actual $calls[1].Arguments -Message 'The DatabaseId property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
