#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'color,createdAt,description,id,isDefault,name,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli `
    -Output @('[{"name":"bug","color":"d73a4a","isDefault":true,"url":"https://github.com/o/r/labels/bug"}]')
try {
    # Act
    $labels = Get-GitHubLabel -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'list', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'Labels are asked for as JSON with a fixed field set'
    Assert-Equal `
        -Expected ([PSCustomObject]@{
            Name = 'bug'
            Color = 'd73a4a'
            IsDefault = $true
            Url = 'https://github.com/o/r/labels/bug'
        }) `
        -Actual $labels `
        -Message 'A single label is that one object, in PascalCase, with the Url that names its repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option, in mixed case where gh wants lower case
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $labels = @(Get-GitHubLabel -Search '--bug' -Sort 'Name' -Order 'DESC' -Limit 100 -Repository ([PSCustomObject]@{ Url = 'https://github.com/o/r' }))
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'label', 'list', '--json', $fields, '--search=--bug', '--sort', 'name', '--order', 'desc', '--limit', '100',
            '--repo', 'https://github.com/o/r'
        ) `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, the search joined to it and the sort and order lower-cased'
    Assert-Equal -Expected 0 -Actual $labels.Count -Message 'No labels writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a limit that asks for nothing, a blank search, a repository given by position, and one given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubLabel -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Get-GitHubLabel -Search ' '
    } -MessageLike '-Search was given but is blank, so it would filter nothing. Give a value, or leave -Search off.' `
        -Message 'A blank search is refused, not dropped to list every label'
    Assert-Throws -ScriptBlock {
        Get-GitHubLabel 'o/r'
    } -MessageLike '*positional parameter cannot be found*' `
        -Message 'A value by position is refused, not taken as a search for labels named o/r'
    Assert-Throws -ScriptBlock {
        Get-GitHubLabel -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of listing the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
