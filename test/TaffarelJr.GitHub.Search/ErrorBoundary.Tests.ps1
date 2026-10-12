#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubSearchTestHelper.ps1')

# The error record a failing call raises, as a catch block sees it.
$catch = {
    param([scriptblock]$Failing)
    try {
        & $Failing
    }
    catch {
        $_
    }
}

$bothAuthors = '-Author and -App cannot be used together: gh searches by one author or the other. Give only one.'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a search that is refused before it reaches gh, from a caller that asks for errors to be silenced
$fake = New-FakeGitHubCli -Output @('[]')
try {
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act
        $script = @"
Find-GitHubIssue -Author 'a' -App 'b' -ErrorAction $preference
'next line ran'
"@
        $result = Invoke-CallerScript -Script $script
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        Assert-Equal -Expected 0 -Actual $calls.Count -Message "Under -ErrorAction $preference no gh call is made"
        Assert-Equal -Expected @('next line ran') -Actual $result.Output `
            -Message "and the call writes nothing, the caller's next line running as for any command"
        Assert-Equal -Expected 1 -Actual $result.Error.Count -Message 'while the refusal is still reported once'
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same refusal, with the caller's errors left as they are
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $record = & $catch { Find-GitHubIssue -Author 'a' -App 'b' }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'RuntimeException,Find-GitHubIssue' -Actual $record.FullyQualifiedErrorId `
        -Message 'The error ID names the kind of failure and the command that raised it'
    Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
        -Message 'its category is an operation that failed'
    Assert-Equal -Expected $bothAuthors -Actual $record.TargetObject `
        -Message 'its target is the text a thrown string carries'
    Assert-Equal -Expected $bothAuthors -Actual $record.Exception.Message -Message 'its message is unchanged'
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and no gh call is made'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same refusal under -ErrorAction Stop
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubIssue -Author 'a' -App 'b' -ErrorAction Stop
    } -MessageLike '*-Author and -App cannot be used together*' `
        -Message 'A call under -ErrorAction Stop stops with the refusal'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and makes no gh call'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a search with neither a query nor a filter, refused by the helper every search function calls
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $result = Invoke-CallerScript -Script @'
Find-GitHubCode -ErrorAction SilentlyContinue
'next line ran'
'@
    $record = & $catch { Find-GitHubCode }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('next line ran') -Actual $result.Output `
        -Message 'A search that would cover all of GitHub finds nothing'
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and runs no gh search'
    Assert-Equal -Expected 'RuntimeException,Find-GitHubCode' -Actual $record.FullyQualifiedErrorId `
        -Message 'The refusal of the helper is raised by the search function'
    Assert-That -Condition ($record.Exception.Message -like '*Give a query*') -Message 'with the helper''s message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value a parameter's validation refuses, from a caller that silences errors
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $result = Invoke-CallerScript -Script @'
Find-GitHubCommit -Query 'fix' -Limit 5000 -ErrorAction SilentlyContinue
'next line ran'
'@
    $record = & $catch { Find-GitHubCommit -Query 'fix' -Limit 5000 }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('next line ran') -Actual $result.Output -Message 'A refused -Limit gives no results'
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and no gh call is made'
    Assert-Equal -Expected 'ParameterArgumentValidationError,Find-GitHubCommit' -Actual $record.FullyQualifiedErrorId `
        -Message 'The refusal is a parameter validation error of the command'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh printing something that is not JSON, so a typed exception comes from Core's parser
$fake = New-FakeGitHubCli -Output @('Welcome to the GitHub CLI')
try {
    # Act
    $record = & $catch { Find-GitHubRepository -Query 'cli' }

    # Assert
    Assert-Equal -Expected 'InvalidDataException,ConvertFrom-GitHubJson,Find-GitHubRepository' `
        -Actual $record.FullyQualifiedErrorId -Message 'A typed exception from Core keeps its type as the ID'
    Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
        -Message 'and its category'
    Assert-That -Condition ($record.Exception.Message -like "gh's output is not valid JSON*") `
        -Message 'with the message unchanged'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh failing, for every function of the module
$cases = @(
    @{ Name = 'Find-GitHubCode'; Call = { Find-GitHubCode -Query 'x' } }
    @{ Name = 'Find-GitHubCommit'; Call = { Find-GitHubCommit -Query 'x' } }
    @{ Name = 'Find-GitHubIssue'; Call = { Find-GitHubIssue -Query 'x' } }
    @{ Name = 'Find-GitHubPullRequest'; Call = { Find-GitHubPullRequest -Query 'x' } }
    @{ Name = 'Find-GitHubRepository'; Call = { Find-GitHubRepository -Query 'x' } }
)
$fake = New-FakeGitHubCli -ErrorOutput @('gh is down') -ExitCode 1
try {
    foreach ($case in $cases) {
        # Act
        $record = & $catch $case.Call

        # Assert
        Assert-Equal -Expected "RuntimeException,Invoke-GitHubCommand,$($case.Name)" `
            -Actual $record.FullyQualifiedErrorId `
            -Message "$($case.Name) raises Core's failure under its own name, after the command that raised it"
        Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
            -Message 'in the category of an operation that failed'
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the author and app clash, and a semantic search with a sort, for the two functions that check them
$fake = New-FakeGitHubCli -Output @('[]')
try {
    $cases = @(
        @{
            Name = 'Find-GitHubPullRequest'
            Call = { Find-GitHubPullRequest -Author 'a' -App 'b' }
            Message = '*-Author and -App cannot be used together*'
        }
        @{
            Name = 'Find-GitHubIssue'
            Call = { Find-GitHubIssue -Query 'x' -SearchType semantic -Sort created }
            Message = '*-SearchType semantic and -Sort cannot be used together*'
        }
    )

    foreach ($case in $cases) {
        # Act
        $record = & $catch $case.Call

        # Assert
        Assert-Equal -Expected "RuntimeException,$($case.Name)" -Actual $record.FullyQualifiedErrorId `
            -Message "$($case.Name) raises its own refusal under its own name"
        Assert-That -Condition ($record.Exception.Message -like $case.Message) -Message 'with the message unchanged'
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and no gh call is made'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
