#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"id":1,"name":"CI","path":".github/workflows/ci.yml","state":"active"}]')
try {
    # Act
    $workflows = Get-GitHubWorkflow -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'list', '--json', 'id,name,path,state', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message 'Workflows are asked for as JSON with a fixed field set'
    Assert-That -Condition ($workflows -isnot [array]) `
        -Message 'A single workflow is written as that one object, not wrapped in an array'
    Assert-Equal -Expected '.github/workflows/ci.yml' -Actual $workflows.Path -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - disabled ones too, capped
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $workflows = @(Get-GitHubWorkflow -All -Limit 10)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'list', '--json', 'id,name,path,state', '--all', '--limit', '10') `
        -Actual $call.Arguments `
        -Message '-All and -Limit become their gh flags'
    Assert-Equal -Expected 0 -Actual $workflows.Count `
        -Message 'No workflows writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow named like a timestamp
$json = '[{"id":1,"name":"2026-01-02T03:04:05Z","path":".github/workflows/n.yml","state":"active"}]'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $workflow = Get-GitHubWorkflow

    # Assert
    Assert-Equal -Expected '2026-01-02T03:04:05Z' -Actual $workflow.Name `
        -Message 'A name that looks like a timestamp stays the text it is'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - workflows listed with and without -Repository
$fake = New-FakeGitHubCli -Output @('[{"id":1,"name":"CI","path":".github/workflows/ci.yml","state":"active"}]')
try {
    # Act
    $given = Get-GitHubWorkflow -Repository 'other/repo'
    $current = Get-GitHubWorkflow

    # Assert
    Assert-Equal -Expected 'other/repo' -Actual $given.Repository `
        -Message 'Each workflow carries the -Repository it was read from'
    Assert-That -Condition ($null -ne $current.PSObject.Properties['Repository'] -and $null -eq $current.Repository) `
        -Message 'and one listed from the current repository carries a $null Repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same repository named as a URL and as OWNER/REPO, and one on another host
$fake = New-FakeGitHubCli -Output @('[{"id":1,"name":"CI","path":".github/workflows/ci.yml","state":"active"}]')
try {
    # Act
    $viaUrl = Get-GitHubWorkflow -Repository 'https://github.com/o/r.git'
    $viaName = Get-GitHubWorkflow -Repository 'o/r'
    $other = Get-GitHubWorkflow -Repository 'https://x-access-token:SENTINEL@ghe.example.com/o/r'

    # Assert
    Assert-Equal -Expected @('o/r', 'o/r') -Actual @($viaUrl.Repository, $viaName.Repository) `
        -Message 'Where-Object Repository -EQ OWNER/REPO finds a workflow however its repository was named'
    Assert-Equal -Expected 'ghe.example.com/o/r' -Actual $other.Repository `
        -Message 'A workflow on another host carries HOST/OWNER/REPO, with no credential'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that ask for nothing, and a repository given positionally
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubWorkflow -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Get-GitHubWorkflow -Repository $null
    } -MessageLike '-Repository was given, but it is $null - leave it out to use*' `
        -Message 'A -Repository given as $null is refused, not taken for the current directory''s'
    Assert-Throws -ScriptBlock {
        Get-GitHubWorkflow 'o/r'
    } -MessageLike '*positional parameter cannot be found*' `
        -Message 'Nothing is positional, so a repository is not taken for a limit'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
