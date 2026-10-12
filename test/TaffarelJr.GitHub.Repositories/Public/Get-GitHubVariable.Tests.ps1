#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,name,numSelectedRepos,selectedReposURL,updatedAt,value,visibility'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one variable by name
$fake = New-FakeGitHubCli -Output @('{"name":"CI_LANGUAGES","value":"dotnet"}')
try {
    # Act
    $variable = Get-GitHubVariable -Name 'CI_LANGUAGES' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'get', '--json', $fields, '--repo', 'o/r', '--', 'CI_LANGUAGES') `
        -Actual $call.Arguments `
        -Message '-Name asks gh for that one variable'
    Assert-Equal -Expected ([PSCustomObject]@{ Name = 'CI_LANGUAGES'; Value = 'dotnet'; Repository = 'o/r' }) `
        -Actual $variable `
        -Message 'The variable comes back as one object, saying which repository it is in'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every variable of an environment, and of an organization
$fake = New-FakeGitHubCli -Output @('[{"name":"A","value":"1"}]')
try {
    # Act
    $environment = Get-GitHubVariable -Environment 'prod'
    $organization = Get-GitHubVariable -Organization 'org'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('variable', 'list', '--json', $fields, '--env=prod') -Actual $calls[0].Arguments `
        -Message 'Without -Name, an environment''s variables are listed with --env'
    Assert-Equal -Expected ([PSCustomObject]@{ Name = 'A'; Value = '1'; Repository = $null; Environment = 'prod' }) `
        -Actual $environment `
        -Message 'and say which environment, of the current directory''s repository'
    Assert-Equal -Expected @('variable', 'list', '--json', $fields, '--org=org') -Actual $calls[1].Arguments `
        -Message 'An organization''s are listed with --org'
    Assert-Equal -Expected ([PSCustomObject]@{ Name = 'A'; Value = '1'; Organization = 'org' }) -Actual $organization `
        -Message 'and say which organization'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no variables
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $variables = @(Get-GitHubVariable)

    # Assert
    Assert-Equal -Expected 0 -Actual $variables.Count `
        -Message 'No variables writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an organization whose name gh would read as an option, and an environment that starts with a dash
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubVariable -Environment '-x' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'list', '--json', $fields, '--env=-x') -Actual $call.Arguments `
        -Message 'The environment travels joined to its flag, so a dash-leading one stays a value'
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Organization '-x'
    } -MessageLike "*'-x' is not an organization name: give letters, digits, and dashes." `
        -Message 'while an organization gh would read as an option is refused'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - scopes gh refuses together, blank scopes and names, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Environment 'prod' -Organization 'org'
    } -MessageLike '-Environment and -Organization cannot be used together: a variable lives in one place - a repository, one of its environments, or an organization. Give only one.' `
        -Message 'An environment and an organization together are refused, saying why'
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Organization 'org' -Repository 'o/r'
    } -MessageLike '-Organization and -Repository cannot be used together: *' `
        -Message 'as are an organization and a repository'
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Environment ''
    } -MessageLike "*-Environment is blank: give the environment's name, or leave it out." `
        -Message 'A blank environment is refused, not sent to gh'
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Name ''
    } -MessageLike '-Name was given but is blank, so it would list every variable. Give a value, or leave -Name off.' `
        -Message 'A blank name is refused, not taken as listing every variable'
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Name ' '
    } -MessageLike '-Name was given but is blank, so it would list every variable. Give a value, or leave -Name off.' `
        -Message 'as is a whitespace one'
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Name $null
    } -MessageLike '-Name was given but is blank, so it would list every variable. Give a value, or leave -Name off.' `
        -Message 'and $null, as a lookup that found nothing gives'
    Assert-Throws -ScriptBlock {
        Get-GitHubVariable -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of reading the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
