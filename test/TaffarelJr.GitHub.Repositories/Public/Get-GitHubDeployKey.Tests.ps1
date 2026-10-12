#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"id":1,"title":"deploy","readOnly":true}]')
try {
    # Act
    $keys = Get-GitHubDeployKey -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('repo', 'deploy-key', 'list', '--json', 'createdAt,id,key,readOnly,title', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message 'The keys are asked for as JSON with a fixed field set'
    Assert-Equal -Expected ([PSCustomObject]@{ Id = [long]1; Title = 'deploy'; ReadOnly = $true; Repository = 'o/r' }) `
        -Actual $keys `
        -Message 'A single key is that one object, in PascalCase, saying which repository it was listed from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository, and a repository object
$fake = New-FakeGitHubCli -Output @('[{"id":1}]')
try {
    # Act
    $here = Get-GitHubDeployKey
    Get-GitHubDeployKey -Repository ([PSCustomObject]@{ NameWithOwner = 'o/r' }) | Out-Null
    Get-GitHubDeployKey 'o/positional' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected ([PSCustomObject]@{ Id = [long]1; Repository = $null }) -Actual $here `
        -Message 'A key listed from the current directory''s repository has a $null Repository'
    Assert-Equal `
        -Expected @('repo', 'deploy-key', 'list', '--json', 'createdAt,id,key,readOnly,title', '--repo', 'o/r') `
        -Actual $calls[1].Arguments `
        -Message 'A repository object is read by its NameWithOwner, not its text'
    Assert-Equal `
        -Expected @(
            'repo', 'deploy-key', 'list', '--json', 'createdAt,id,key,readOnly,title', '--repo', 'o/positional'
        ) `
        -Actual $calls[2].Arguments `
        -Message 'The repository is the one parameter taken by position'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no keys
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $keys = @(Get-GitHubDeployKey)

    # Assert
    Assert-Equal -Expected 0 -Actual $keys.Count -Message 'No keys writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubDeployKey -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of listing the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
