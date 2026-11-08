#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

# A function of another module, which calls Core as a TaffarelJr.GitHub.* module does.
$other = New-Module -Name OtherGitHubModule -ScriptBlock {
    function Invoke-FromOther {
        [CmdletBinding()]
        param()

        Invoke-GitHubCommand -Activity 'From another module' -Argument @('api', 'user') | Out-Null
        Invoke-GitHubApi -Endpoint 'user' | Out-Null
    }
} | Import-Module -PassThru

$token = 'ghp_' + ('A' * 36)

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh call with -Verbose, an argument holding a space, and a repository
$fake = New-FakeGitHubCli -Output @('{}')
try {
    $call = {
        Invoke-GitHubCommand -Activity 'Listing pull requests' -Argument @('pr', 'list', '--title', 'a b') `
            -Repository 'o/r' -Verbose
    }

    # Act
    $lines = @(Get-VerboseLine $call)

    # Assert
    Assert-Equal -Expected @('Listing pull requests: gh pr list --title ''a b'' --repo o/r') -Actual $lines `
        -Message 'The activity and the whole command line are written before gh runs, a spaced argument quoted'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same call without -Verbose
$fake = New-FakeGitHubCli -Output @('{}')
try {
    $call = {
        Invoke-GitHubCommand -Activity 'Listing pull requests' -Argument @('pr', 'list') -Repository 'o/r'
    }

    # Act
    $lines = @(Get-VerboseLine $call)

    # Assert
    Assert-Equal -Expected @() -Actual $lines -Message 'Nothing is written unless a caller asks'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository URL that carries a token, and a token that stands alone in the activity and an argument
$fake = New-FakeGitHubCli -Output @('{}')
try {
    $call = {
        Invoke-GitHubCommand -Activity "Reading $token" -Argument @('api', 'x', $token) `
            -Repository "https://x-access-token:$token@github.com/o/r" -Verbose
    }

    # Act
    $lines = @(Get-VerboseLine $call)

    # Assert
    Assert-Equal -Expected @('Reading ***: gh api x *** --repo https://***@github.com/o/r') -Actual $lines `
        -Message 'Every credential is hidden, as a failure message hides it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text for gh's standard input
$fake = New-FakeGitHubCli -Output @('{}')
try {
    $call = {
        Invoke-GitHubCommand -Activity 'Posting' -Argument @('api', 'x', '--input', '-') -StdIn 'SECRET-BODY' -Verbose
    }

    # Act
    $lines = @(Get-VerboseLine $call)

    # Assert
    Assert-Equal -Expected @('Posting: gh api x --input - (with standard input)') -Actual $lines `
        -Message 'Standard input is mentioned and never shown'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the API function, once for a plain read and once with a method, a field, and a body
$fake = New-FakeGitHubCli -Output @('{}')
try {
    $readCall = { Invoke-GitHubApi -Endpoint 'repos/o/r' -Verbose }
    $writeCall = {
        Invoke-GitHubApi -Endpoint 'repos/o/r' -Method POST -Field @{ a = 1 } -Body 'SECRET-BODY' -Verbose
    }

    # Act
    $read = @(Get-VerboseLine $readCall)
    $write = @(Get-VerboseLine $writeCall)

    # Assert
    $expectedRead = @(
        'Calling repos/o/r with gh''s default method'
        'Calling repos/o/r: gh api repos/o/r'
    )
    Assert-Equal -Expected $expectedRead -Actual $read `
        -Message 'The API call is described, then the gh command line that makes it'
    $expectedWrite = @(
        'Performing the operation "Call the GitHub API" on target "POST repos/o/r".'
        'Calling repos/o/r with POST'
        'Calling repos/o/r: gh api repos/o/r --method POST --field a=1 --input - (with standard input)'
    )
    Assert-Equal -Expected $expectedWrite -Actual $write `
        -Message 'with the method, and never the body, after the line -Verbose gives any call that changes something'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a caller's own function that sets $VerbosePreference in its scope
function Read-Repository {
    [CmdletBinding()]
    param()

    $VerbosePreference = 'Continue'
    Invoke-GitHubCommand -Activity 'Reading the repository' -Argument @('repo', 'view') | Out-Null
}
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    $lines = @(Get-VerboseLine { Read-Repository })
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath Function:Read-Repository
}

# Assert
Assert-Equal -Expected @('Reading the repository: gh repo view') -Actual $lines `
    -Message 'Core follows a $VerbosePreference its caller set in its own scope'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a function of another module, called with -Verbose
$fake = New-FakeGitHubCli -Output @('{}')
try {
    $call = { Invoke-FromOther -Verbose }

    # Act
    $lines = @(Get-VerboseLine $call)

    # Assert
    $expected = @(
        'From another module: gh api user'
        'Calling user with gh''s default method'
        'Calling user: gh api user'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'Core follows the -Verbose of the function of another module that calls it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same function, with the caller's preference set instead of the switch
$fake = New-FakeGitHubCli -Output @('{}')
Set-Variable -Scope Global -Name VerbosePreference -Value 'Continue'
try {
    $call = { Invoke-FromOther }
    $quietCall = { Invoke-FromOther -Verbose:$false }

    # Act
    $lines = @(Get-VerboseLine $call)
    $quiet = @(Get-VerboseLine $quietCall)

    # Assert
    Assert-Equal -Expected 3 -Actual $lines.Count -Message 'Core follows the caller''s $VerbosePreference'
    Assert-Equal -Expected @() -Actual $quiet -Message 'and -Verbose:$false overrides it'
}
finally {
    Set-Variable -Scope Global -Name VerbosePreference -Value 'SilentlyContinue'
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same function, with nothing asked for
$fake = New-FakeGitHubCli -Output @('{}')
try {
    $call = { Invoke-FromOther }

    # Act
    $lines = @(Get-VerboseLine $call)

    # Assert
    Assert-Equal -Expected @() -Actual $lines `
        -Message 'A function of another module not asked for -Verbose writes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

Remove-Module -Name $other.Name -Force

exit (Complete-TestRun)
