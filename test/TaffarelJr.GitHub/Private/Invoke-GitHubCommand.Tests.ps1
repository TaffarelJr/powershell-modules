#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub/Private/Invoke-GitHubCommand.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake gh that answers with two lines
$fake = New-FakeGitHubCli -Output @('first', 'second')
try {
    # Act
    $out = Invoke-GitHubCommand -Activity 'Listing' -Arguments @('pr', 'list') -Repository 'owner/repo'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected @('first', 'second') -Actual $out -Message "gh's output lines are returned"
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'gh is invoked exactly once'
    Assert-Equal -Expected @('pr', 'list', '--repo', 'owner/repo') -Actual $calls[0].Arguments -Message '-Repository is appended as --repo after the given arguments'
    Assert-Equal -Expected '' -Actual $calls[0].StdIn -Message 'Nothing is piped to gh without -StdIn'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one line of output, no -Repository
$fake = New-FakeGitHubCli -Output @('only')
try {
    # Act
    $out = Invoke-GitHubCommand -Activity 'Reading' -Arguments @('auth', 'token')
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-That -Condition ($out -is [array]) -Message 'A single output line is still returned as an array'
    Assert-Equal -Expected 1 -Actual $out.Count -Message 'The single line is the only element'
    Assert-Equal -Expected @('auth', 'token') -Actual $calls[0].Arguments -Message 'Without -Repository, no --repo is added'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that must only ever travel on stdin
$fake = New-FakeGitHubCli
try {
    # Act
    Invoke-GitHubCommand -Activity 'Setting' -Arguments @('secret', 'set', 'NAME') -StdIn 'hunter2' | Out-Null
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 'hunter2' -Actual $calls[0].StdIn -Message '-StdIn reaches gh on its standard input'
    Assert-That -Condition ($calls[0].Arguments -notcontains 'hunter2') -Message 'The piped value never appears among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails
$fake = New-FakeGitHubCli -Output @('boom') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubCommand -Activity 'Creating' -Arguments @('pr', 'create')
    } -Message 'A non-zero exit throws by default'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails, but the caller asked to tolerate that
$fake = New-FakeGitHubCli -Output @('not found') -ExitCode 1
try {
    # Act
    $result = Invoke-GitHubCommand -Activity 'Probing' -Arguments @('api', 'repos/o/r') -Tolerant

    # Assert
    Assert-Equal -Expected $false -Actual $result.Ok -Message '-Tolerant reports a failure as Ok = $false instead of throwing'
    Assert-Equal -Expected 1 -Actual $result.ExitCode -Message "-Tolerant carries gh's exit code"
    Assert-Equal -Expected @('not found') -Actual $result.Output -Message "-Tolerant keeps gh's output"
    Assert-Equal -Expected 0 -Actual $LASTEXITCODE -Message 'A tolerated failure does not leave $LASTEXITCODE behind'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
