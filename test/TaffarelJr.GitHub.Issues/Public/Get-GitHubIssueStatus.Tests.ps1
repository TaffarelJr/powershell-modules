#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = & $module { Get-GitHubIssueField }

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{"assigned":[],"createdBy":[{"number":1,"title":"Roadmap"}],"mentioned":[]}')
try {
    # Act
    $status = Get-GitHubIssueStatus -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'status', '--json', $fields, '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Status is asked for as JSON with the default field set'
    Assert-Equal -Expected 0 -Actual $status.Assigned.Count -Message 'An empty group is an empty array'
    Assert-Equal -Expected 1 -Actual $status.CreatedBy.Count -Message "The user's own issues are an array"
    Assert-Equal -Expected 'Roadmap' -Actual $status.CreatedBy[0].Title `
        -Message 'Each issue in a group is parsed and re-cased'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the fields named
$fake = New-FakeGitHubCli -Output @('{"assigned":[],"createdBy":[],"mentioned":[]}')
try {
    # Act
    Get-GitHubIssueStatus -Property 'number', 'title' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'status', '--json', 'number,title,url')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message '-Property replaces the default fields, with url always added'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the repository given as a repository object
$repository = [PSCustomObject]@{ Url = 'https://github.com/o/r'; NameWithOwner = 'o/r' }
$fake = New-FakeGitHubCli -Output @('{"assigned":[],"createdBy":[],"mentioned":[]}')
try {
    # Act
    Get-GitHubIssueStatus -Repository $repository | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('issue', 'status', '--json', $fields, '--repo', 'https://github.com/o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'A repository object is read by its Url, not by its text'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a misspelled parameter, a repository given by position, and one
# given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubIssueStatus -Repositry 'o/other'
    } -MessageLike "*A parameter cannot be found that matches parameter name 'Repositry'*" `
        -Message 'A misspelled parameter is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Get-GitHubIssueStatus 'o/r'
    } -MessageLike '*A positional parameter cannot be found that accepts argument ''o/r''*' `
        -Message 'A value given by position is refused, not taken for a field'
    Assert-Throws -ScriptBlock {
        Get-GitHubIssueStatus -Repository $null
    } -MessageLike "-Repository was given, but it is `$null - leave it out to use the current directory's repository." `
        -Message 'A -Repository given as $null is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'before gh reads the current directory''s repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
