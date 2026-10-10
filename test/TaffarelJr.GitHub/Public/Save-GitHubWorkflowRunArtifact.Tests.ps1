#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one named artifact of one run
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubWorkflowRunArtifact -Id 123 -Name @('packages') -Destination 'out' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'download', '123', '--name', 'packages', '--dir', 'out', '--repo', 'o/r') -Actual $call.Arguments -Message 'The run is positional and each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - artifacts by name and pattern across every run
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubWorkflowRunArtifact -Name @('a', 'b') -Pattern @('*-report')
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'download', '--name', 'a', '--name', 'b', '--pattern', '*-report') -Actual $call.Arguments -Message 'Without -Id, one --name per name and one --pattern per pattern'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
