#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubCoreTestHelper.ps1')

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

$paginatePost = 'Calling repos/o/r with -Paginate needs -Method GET: gh fetches further pages only for a GET of ' +
    'a REST endpoint (or for graphql), and refuses --paginate with POST.'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a call that is refused before it reaches gh, from a caller that asks for errors to be silenced
$fake = New-FakeGitHubCli -Output @('[]')
try {
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act
        $script = @"
Invoke-GitHubApi -Endpoint 'repos/o/r' -Paginate -Method POST -ErrorAction $preference
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
    $record = & $catch { Invoke-GitHubApi -Endpoint 'repos/o/r' -Paginate -Method POST }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'RuntimeException,Invoke-GitHubApi' -Actual $record.FullyQualifiedErrorId `
        -Message 'The error ID names the kind of failure and the command that raised it'
    Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
        -Message 'its category is an operation that failed'
    Assert-Equal -Expected $paginatePost -Actual $record.TargetObject `
        -Message 'its target is the text a thrown string carries'
    Assert-Equal -Expected $paginatePost -Actual $record.Exception.Message -Message 'its message is unchanged'
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
        Invoke-GitHubApi -Endpoint 'repos/o/r' -Paginate -Method POST -ErrorAction Stop
    } -MessageLike '*needs -Method GET*' -Message 'A call under -ErrorAction Stop stops with the refusal'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and makes no gh call'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a script block that fails with a typed exception, run by a function that cleans up after it
$kept = @{}

# Act
$record = & $catch {
    Use-GitHubTextFile -Text 'x' -ScriptBlock {
        param($Path)
        $kept.Path = $Path
        throw [System.TimeoutException]::new('Waited too long.')
    }
}

# Assert
Assert-Equal -Expected 'TimeoutException,Use-GitHubTextFile' -Actual $record.FullyQualifiedErrorId `
    -Message 'A typed exception keeps its own type as the error ID'
Assert-Equal -Expected 'OperationTimeout' -Actual $record.CategoryInfo.Category.ToString() `
    -Message 'and gets the category of its kind'
Assert-Equal -Expected 'Waited too long.' -Actual $record.Exception.Message -Message 'and its own message'
Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $kept.Path) -Message 'The file is deleted all the same'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a built-in cmdlet that fails inside the script block
$missing = Join-Path ([System.IO.Path]::GetTempPath()) "gh-core-missing-$([Guid]::NewGuid())"

# Act
$record = & $catch {
    Use-GitHubTextFile -Text 'x' -ScriptBlock {
        Get-Item -LiteralPath $missing -ErrorAction Stop
    }
}

# Assert
Assert-Equal -Expected 'PathNotFound,Microsoft.PowerShell.Commands.GetItemCommand,Use-GitHubTextFile' `
    -Actual $record.FullyQualifiedErrorId -Message 'A built-in cmdlet''s own error ID is kept, with the command added'
Assert-Equal -Expected 'ObjectNotFound' -Actual $record.CategoryInfo.Category.ToString() -Message 'and its category'
Assert-Equal -Expected $missing -Actual $record.TargetObject -Message 'and its target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a public function that fails inside another public function of the module
$listMessage = 'Give one repository at a time, not a list of 2; call once per repository.'

# Act
$record = & $catch { Resolve-GitHubRepositoryArgument -Value @('a/b', 'c/d') -Given $true }

# Assert
$id = 'RuntimeException,ConvertTo-GitHubRepositoryReference,Resolve-GitHubRepositoryArgument'
Assert-Equal -Expected $id -Actual $record.FullyQualifiedErrorId `
    -Message 'An error from a function this one calls keeps that function''s name in its ID, then adds its own'
Assert-Equal -Expected $listMessage -Actual $record.Exception.Message -Message 'with the message unchanged'
Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() -Message 'and its category'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a host name a parameter's validation refuses, from a caller that silences errors
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    $result = Invoke-CallerScript -Script @'
Test-GitHubApi -Endpoint 'repos/o/r' -Hostname 'https://ghe.example.com' -ErrorAction SilentlyContinue
'next line ran'
'@
    $record = & $catch { Test-GitHubApi -Endpoint 'repos/o/r' -Hostname 'https://ghe.example.com' }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('next line ran') -Actual $result.Output -Message 'A refused -Hostname gives no answer'
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and no gh call is made'
    Assert-Equal -Expected 'ParameterArgumentValidationError,Test-GitHubApi' -Actual $record.FullyQualifiedErrorId `
        -Message 'The refusal is a parameter validation error of the command'
    Assert-That -Condition ($record.Exception.Message -like "*'https://ghe.example.com' is not a host name*") `
        -Message 'and names the value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text that is not JSON, piped to a function that parses what it
# gathered in its end block, from a caller that silences errors
foreach ($preference in 'SilentlyContinue', 'Ignore') {
    # Act
    $result = Invoke-CallerScript -Script @"
'{', 'not json' | ConvertFrom-GitHubJson -ErrorAction $preference
'next line ran'
"@

    # Assert
    Assert-Equal -Expected @('next line ran') -Actual $result.Output `
        -Message "Under -ErrorAction $preference a failure in the end block writes nothing"
    Assert-Equal -Expected 1 -Actual $result.Error.Count -Message 'and is still reported once'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a poll that New-GitHubPoll never made, handed to the two functions that read one
$cases = @(
    @{ Name = 'Test-GitHubPollExpired'; Call = { Test-GitHubPollExpired -Poll @{} } }
    @{ Name = 'Wait-GitHubPoll'; Call = { Wait-GitHubPoll -Poll @{} } }
)

# Act / Assert
foreach ($case in $cases) {
    $record = & $catch $case.Call
    Assert-Equal -Expected "PropertyNotFoundStrict,$($case.Name)" -Actual $record.FullyQualifiedErrorId `
        -Message "$($case.Name) refuses it with an error naming itself"
    Assert-Equal -Expected 'InvalidOperation' -Actual $record.CategoryInfo.Category.ToString() `
        -Message 'in the category of an operation that failed'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a poll whose sleep fails
$poll = New-GitHubPoll -TimeoutSeconds 5 -PollSeconds 1
$poll.Sleep = { throw 'The sleep failed.' }

# Act
$record = & $catch { Wait-GitHubPoll -Poll $poll }

# Assert
Assert-Equal -Expected 'RuntimeException,Wait-GitHubPoll' -Actual $record.FullyQualifiedErrorId `
    -Message 'A failure of the sleep is raised by Wait-GitHubPoll'
Assert-Equal -Expected 'The sleep failed.' -Actual $record.Exception.Message -Message 'with its own message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the functions that hide a credential or build a context, with the one they call failing
$core = Get-Module -Name 'TaffarelJr.GitHub.Core'
& $core {
    function script:Hide-UrlCredential {
        throw [System.InvalidOperationException]::new('The hider failed.')
    }
    function script:New-GitHubJsonContext {
        throw [System.InvalidOperationException]::new('The context failed.')
    }
}
$cases = @(
    @{
        Name = 'Get-GitHubTimeoutMessage'
        Call = { Get-GitHubTimeoutMessage -Subject 'Waited.' }
        Message = 'The hider failed.'
    }
    @{
        Name = 'Format-GitHubRepositoryName'
        Call = { Format-GitHubRepositoryName -Repository 'o/r' }
        Message = 'The hider failed.'
    }
    @{
        Name = 'ConvertTo-PascalCaseObject'
        Call = { ConvertTo-PascalCaseObject -InputObject @{ a_b = 1 } }
        Message = 'The context failed.'
    }
)

# Act / Assert
foreach ($case in $cases) {
    $record = & $catch $case.Call
    Assert-Equal -Expected "InvalidOperationException,$($case.Name)" -Actual $record.FullyQualifiedErrorId `
        -Message "A failure inside $($case.Name) is raised by it, keeping the exception's type"
    Assert-Equal -Expected $case.Message -Actual $record.Exception.Message -Message 'and its message'
}

exit (Complete-TestRun)
