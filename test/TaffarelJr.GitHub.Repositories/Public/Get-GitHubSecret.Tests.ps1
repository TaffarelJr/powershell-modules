#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'name,numSelectedRepos,selectedReposURL,updatedAt,visibility'
$secret = '[{"name":"NUGET_KEY","visibility":"private"}]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository's secrets
$fake = New-FakeGitHubCli -Output @($secret)
try {
    # Act
    $secrets = Get-GitHubSecret -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The repository is passed as --repo with a fixed field set'
    Assert-Equal `
        -Expected ([PSCustomObject]@{
            Name = 'NUGET_KEY'
            Visibility = 'private'
            Repository = 'o/r'
            Application = 'actions'
        }) `
        -Actual $secrets `
        -Message 'A single secret is that one object, saying it is the repository''s Actions secret'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository, an application asked for in mixed case
$fake = New-FakeGitHubCli -Output @($secret)
try {
    # Act
    $secrets = Get-GitHubSecret -Application 'Dependabot'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--app', 'dependabot') -Actual $call.Arguments `
        -Message 'The application is lower-cased for gh'
    Assert-Equal `
        -Expected ([PSCustomObject]@{
            Name = 'NUGET_KEY'
            Visibility = 'private'
            Repository = $null
            Application = 'dependabot'
        }) `
        -Actual $secrets `
        -Message 'Repository is $null for the current directory''s, and Application the one asked for'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an environment's, an organization's, and the user's secrets
$fake = New-FakeGitHubCli -Output @($secret)
try {
    # Act
    $environment = Get-GitHubSecret -Environment 'prod' `
        -Repository ([PSCustomObject]@{ Url = 'https://github.com/o/r' })
    $organization = Get-GitHubSecret -Organization 'org'
    $user = Get-GitHubSecret -User
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--env=prod', '--repo', 'https://github.com/o/r') `
        -Actual $calls[0].Arguments `
        -Message 'An environment''s secrets are listed with --env, from the repository object''s Url'
    Assert-Equal `
        -Expected ([PSCustomObject]@{
            Name = 'NUGET_KEY'
            Visibility = 'private'
            Repository = 'https://github.com/o/r'
            Environment = 'prod'
        }) `
        -Actual $environment `
        -Message 'and say which repository and environment they belong to'
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--org=org') -Actual $calls[1].Arguments `
        -Message 'An organization''s are listed with --org'
    Assert-Equal `
        -Expected ([PSCustomObject]@{
            Name = 'NUGET_KEY'
            Visibility = 'private'
            Organization = 'org'
            Application = 'actions'
        }) `
        -Actual $organization `
        -Message 'and say which organization'
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--user') -Actual $calls[2].Arguments `
        -Message 'The user''s are listed with --user'
    Assert-Equal `
        -Expected ([PSCustomObject]@{
            Name = 'NUGET_KEY'
            Visibility = 'private'
            User = $true
            Application = 'codespaces'
        }) `
        -Actual $user `
        -Message 'and say they are the user''s Codespaces secrets'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no secrets
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $secrets = @(Get-GitHubSecret)

    # Assert
    Assert-Equal -Expected 0 -Actual $secrets.Count -Message 'No secrets writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an environment whose name starts with a dash
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubSecret -Environment '-x' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--env=-x') -Actual $call.Arguments `
        -Message 'The environment travels joined to its flag, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - scopes gh refuses together, blank and malformed scopes, and a repository given as $null
$place = 'a secret lives in one place - a repository, one of its environments, an organization, or the user. Give only one.'
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Environment 'prod' -Organization 'org'
    } -MessageLike "-Environment and -Organization cannot be used together: $place" `
        -Message 'An environment and an organization together are refused, saying why'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Organization 'org' -User
    } -MessageLike "-Organization and -User cannot be used together: $place" `
        -Message 'as are an organization and the user'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Organization 'org' -Repository 'o/r'
    } -MessageLike "-Organization and -Repository cannot be used together: $place" `
        -Message 'and an organization and a repository'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Environment ' '
    } -MessageLike "*-Environment is blank: give the environment's name, or leave it out." `
        -Message 'A blank environment is refused, not sent to gh'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Organization ''
    } -MessageLike "*'' is not an organization name: give letters, digits, and dashes." `
        -Message 'as is an empty organization'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Organization '-x'
    } -MessageLike "*'-x' is not an organization name: give letters, digits, and dashes." `
        -Message 'and one gh would read as an option'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Environment 'prod' -Application actions
    } -MessageLike '-Application and -Environment cannot be used together: an environment''s secrets are always Actions''. Give only one.' `
        -Message 'An application for an environment, whose secrets are always Actions'', is refused, saying why'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret 'o/r'
    } -MessageLike '*positional parameter cannot be found*' `
        -Message 'A value by position is refused, not taken as an environment'
    Assert-Throws -ScriptBlock {
        Get-GitHubSecret -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of listing the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
