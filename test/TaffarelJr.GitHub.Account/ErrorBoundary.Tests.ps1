#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubAccountTestHelper.ps1')

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

$blankToken = '-Token is blank, and gh would fall back to its browser login: give the token.'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a login refused before it reaches gh, from a caller that asks for errors to be silenced
$fake = New-FakeGitHubCli
try {
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act
        $script = @"
Connect-GitHubAccount -Token ' ' -ErrorAction $preference
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
$fake = New-FakeGitHubCli
try {
    # Act
    $record = & $catch { Connect-GitHubAccount -Token ' ' }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'RuntimeException,Connect-GitHubAccount' -Actual $record.FullyQualifiedErrorId `
        -Message 'The error ID names the kind of failure and the command that raised it'
    Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
        -Message 'its category is an operation that failed'
    Assert-Equal -Expected $blankToken -Actual $record.TargetObject `
        -Message 'its target is the text a thrown string carries'
    Assert-Equal -Expected $blankToken -Actual $record.Exception.Message -Message 'its message is unchanged'
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and no gh call is made'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same refusal under -ErrorAction Stop
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Connect-GitHubAccount -Token ' ' -ErrorAction Stop
    } -MessageLike '*-Token is blank*' -Message 'A call under -ErrorAction Stop stops with the refusal'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and makes no gh call'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a setting that is refused before gh is asked anything, from a caller that silences errors
$fake = New-FakeGitHubCli -Output @('editor=vim')
try {
    # Act
    $result = Invoke-CallerScript -Script @'
Set-GitHubConfig -Name 'editor' -Value "a`nb" -ErrorAction SilentlyContinue
'next line ran'
'@
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count `
        -Message 'A value with a line break neither reads nor changes the settings'
    Assert-Equal -Expected @('next line ran') -Actual $result.Output -Message 'and the call writes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an account name a parameter's validation refuses, from a caller that silences errors
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Invoke-CallerScript -Script @'
Disconnect-GitHubAccount -User 'two words' -ErrorAction SilentlyContinue
'next line ran'
'@
    $record = & $catch { Disconnect-GitHubAccount -User 'two words' }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('next line ran') -Actual $result.Output -Message 'A refused -User removes no login'
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and no gh call is made'
    Assert-Equal -Expected 'ParameterArgumentValidationError,Disconnect-GitHubAccount' `
        -Actual $record.FullyQualifiedErrorId -Message 'The refusal is a parameter validation error of the command'
    Assert-That -Condition ($record.Exception.Message -like "*'two words' is not an account name*") `
        -Message 'and names the value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refusing the change, so the failure comes from Core's command and passes through this one
$fake = New-FakeGitHubCli -ErrorOutput @('unable to determine which account to switch to') -ExitCode 1
try {
    # Act
    $record = & $catch { Switch-GitHubAccount }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Invoke-GitHubCommand,Switch-GitHubAccount' `
        -Actual $record.FullyQualifiedErrorId `
        -Message 'An error from Core keeps the name of the command that raised it, then the one of this module'
    Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
        -Message 'and its category'
    Assert-That -Condition ($record.Exception.Message -like '*Switching the active account failed*') `
        -Message 'with the message unchanged'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh printing something that is not JSON, so a typed exception comes from Core's parser
$fake = New-FakeGitHubCli -Output @('Welcome to the GitHub CLI')
try {
    # Act
    $record = & $catch { Get-GitHubAuthStatus }

    # Assert
    Assert-Equal -Expected 'InvalidDataException,ConvertFrom-GitHubJson,Get-GitHubAuthStatus' `
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
# Arrange - gh failing, for every command of the module
$cases = @(
    @{ Name = 'Clear-GitHubConfigCache'; Call = { Clear-GitHubConfigCache } }
    @{ Name = 'Connect-GitHubAccount'; Call = { Connect-GitHubAccount -Token 'not-a-real-token' } }
    @{ Name = 'Disconnect-GitHubAccount'; Call = { Disconnect-GitHubAccount } }
    @{ Name = 'Get-GitHubAuthStatus'; Call = { Get-GitHubAuthStatus } }
    @{ Name = 'Get-GitHubConfig'; Call = { Get-GitHubConfig -Name 'editor' } }
    @{ Name = 'Get-GitHubOrganization'; Call = { Get-GitHubOrganization } }
    @{ Name = 'Get-GitHubToken'; Call = { Get-GitHubToken } }
    @{ Name = 'Register-GitHubCredentialHelper'; Call = { Register-GitHubCredentialHelper } }
    @{ Name = 'Set-GitHubConfig'; Call = { Set-GitHubConfig -Name 'editor' -Value 'vim' } }
    @{ Name = 'Switch-GitHubAccount'; Call = { Switch-GitHubAccount } }
)
$fake = New-FakeGitHubCli -ErrorOutput @('gh is down') -ExitCode 1
try {
    foreach ($case in $cases) {
        # Act
        $record = & $catch $case.Call

        # Assert
        Assert-That -Condition ($record.FullyQualifiedErrorId -like "*,$($case.Name)") `
            -Message "$($case.Name) raises the failure under its own name (ID: $($record.FullyQualifiedErrorId))"
        Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
            -Message 'in the category of an operation that failed'
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
