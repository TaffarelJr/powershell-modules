#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the endpoint answers
$fake = New-FakeGitHubCli
try {
    # Act
    $exists = Test-GitHubApi -Endpoint 'repos/o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r', '--silent') -Actual $call.Arguments `
        -Message 'The probe asks gh to discard the body'
    Assert-Equal -Expected $true -Actual $exists -Message 'A successful request reports $true'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the endpoint is not there
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Not Found (HTTP 404)') -ExitCode 1
try {
    # Act
    $exists = Test-GitHubApi -Endpoint 'repos/o/missing' -Hostname 'ghe.example'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected $false -Actual $exists -Message 'A 404 reports $false instead of throwing'
    Assert-Equal -Expected @('api', 'repos/o/missing', '--silent', '--hostname', 'ghe.example') `
        -Actual $call.Arguments `
        -Message '-Hostname is passed through'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the other answers that mean "not there"
$answers = @(
    @{ Status = 'A 410'; Message = 'gh: Gone (HTTP 410)' }
    @{ Status = 'A 404 that mentions a rate limit'; Message = 'gh: No rate limit rule found (HTTP 404)' }
    @{ Status = 'A 410 that mentions a rate limit'; Message = 'gh: The rate limit policy is gone (HTTP 410)' }
    @{ Status = 'A bare 404'; Message = 'gh: HTTP 404' }
)
foreach ($answer in $answers) {
    $fake = New-FakeGitHubCli -ErrorOutput @($answer.Message) -ExitCode 1
    try {
        Assert-Equal -Expected $false -Actual (Test-GitHubApi -Endpoint 'repos/o/r') `
            -Message "$($answer.Status) means the thing is not there, reported as `$false"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every other failure, which is not an answer
$failures = @(
    @{
        Status = 'A refused token'
        Message = 'gh: Bad credentials (HTTP 401)'
        ExitCode = 1
        Code = 'HTTP 401'
    }
    @{
        Status = 'a token that may not see it'
        Message = 'gh: Resource not accessible by integration (HTTP 403)'
        ExitCode = 1
        Code = 'HTTP 403'
    }
    @{
        Status = 'no login'
        Message = 'gh: To use GitHub CLI, please run: gh auth login'
        ExitCode = 4
        Code = 'exit 4'
    }
    @{
        Status = 'a rate limit'
        Message = 'gh: API rate limit exceeded for user ID 1. (HTTP 403)'
        ExitCode = 1
        Code = 'HTTP 403'
    }
    @{
        Status = 'a secondary rate limit'
        Message = 'gh: You have exceeded a secondary rate limit. (HTTP 403)'
        ExitCode = 1
        Code = 'HTTP 403'
    }
    @{ Status = 'a 429'; Message = 'gh: Too Many Requests (HTTP 429)'; ExitCode = 1; Code = 'HTTP 429' }
    @{ Status = 'a server error'; Message = 'gh: Server Error (HTTP 500)'; ExitCode = 1; Code = 'HTTP 500' }
    @{ Status = 'a bad gateway'; Message = 'gh: Bad Gateway (HTTP 502)'; ExitCode = 1; Code = 'HTTP 502' }
    @{ Status = 'no network'; Message = 'error connecting to api.github.com'; ExitCode = 1; Code = 'exit 1' }
)
foreach ($failure in $failures) {
    $fake = New-FakeGitHubCli -ErrorOutput @($failure.Message) -ExitCode $failure.ExitCode
    try {
        $expected = "Probing repos/o/r failed ($($failure.Code)):`n$($failure.Message)"
        Assert-Throws -ScriptBlock {
            Test-GitHubApi -Endpoint 'repos/o/r'
        } -MessageLike ([WildcardPattern]::Escape($expected)) `
            -Message "$($failure.Status) throws with its status and gh's reason, since it is not an answer"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an endpoint holding a credential, which gh echoes
$endpoint = 'https://u:SENTINEL@ghe.example.com/api/v3/repos/o/r'
$fake = New-FakeGitHubCli -ErrorOutput @("Get `"$endpoint`": Forbidden (HTTP 403)") -ExitCode 1
try {
    $expected = "Probing https://***@ghe.example.com/api/v3/repos/o/r failed (HTTP 403):`n" +
    'Get "https://***@ghe.example.com/api/v3/repos/o/r": Forbidden (HTTP 403)'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Test-GitHubApi -Endpoint $endpoint
    } -MessageLike ([WildcardPattern]::Escape($expected)) `
        -Message 'The credential is hidden in the endpoint and in what gh printed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - a machine with no gh on its PATH
$savedPath = $env:PATH
$env:PATH = ''
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Test-GitHubApi -Endpoint 'repos/o/r'
    } -MessageLike '*gh was not found on PATH*' -Message 'A missing gh throws instead of reading as "not there"'
}
finally {
    $env:PATH = $savedPath
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an endpoint gh would read as an option
Assert-Throws -ScriptBlock {
    Test-GitHubApi -Endpoint '--hostname'
} -MessageLike "*'--hostname' starts with '-', which gh would read as an option." `
    -Message 'An endpoint starting with a dash is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake that answers 404, which a blank endpoint would read as "gone"
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Not Found (HTTP 404)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Test-GitHubApi -Endpoint ' ' } `
        -MessageLike "Cannot validate argument on parameter 'Endpoint'. -Endpoint is blank: *" `
        -Message 'A blank endpoint is refused'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is run'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - host names gh could only fail to find, and an empty one
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($hostname in 'ghe.example:8443', '') {
        Assert-Throws -ScriptBlock {
            Test-GitHubApi -Endpoint 'user' -Hostname $hostname
        } -MessageLike "*'$hostname' is not a host name: give it bare*or leave -Hostname out for the default host." `
            -Message "-Hostname '$hostname' is refused as Assert-GitHubHostname refuses it"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is run'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
exit (Complete-TestRun)
