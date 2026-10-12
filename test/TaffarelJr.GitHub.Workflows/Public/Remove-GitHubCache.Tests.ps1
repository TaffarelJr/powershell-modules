#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one cache by id
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubCache -Id '1234' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'delete', '1234', '--repo', 'o/r') -Actual $call.Arguments -Message 'The cache id is positional'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every cache, scoped to a ref
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubCache -All -Ref 'refs/heads/main' -SucceedOnNoCaches
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'delete', '--all', '--ref', 'refs/heads/main', '--succeed-on-no-caches') -Actual $call.Arguments -Message '-All, -Ref, and -SucceedOnNoCaches become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - cache ids from the pipeline, as Get-GitHubCache returns them
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ Id = '1' }, [PSCustomObject]@{ Id = '2' }) | Remove-GitHubCache
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped cache is deleted in its own call'
    Assert-Equal -Expected @('cache', 'delete', '2') -Actual $calls[1].Arguments -Message 'The Id property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
