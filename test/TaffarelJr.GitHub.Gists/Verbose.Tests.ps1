#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$read = @(
    'Calling gists/abc123 with gh''s default method'
    'Calling gists/abc123: gh api gists/abc123'
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a read with its own -Verbose
$fake = New-FakeGitHubCli -Output @('{"id":"abc123"}')
try {
    # Act
    $lines = @(Get-VerboseLine { Get-GitHubGist -Id 'abc123' -Verbose })

    # Assert
    Assert-Equal -Expected $read -Actual $lines -Message 'A call with -Verbose prints the gh command line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the read from a function whose scope sets $VerbosePreference
$fake = New-FakeGitHubCli -Output @('{"id":"abc123"}')
try {
    # Act
    $lines = @(Get-VerboseLine { Invoke-VerboseCaller { Get-GitHubGist -Id 'abc123' } })

    # Assert
    Assert-Equal -Expected $read -Actual $lines `
        -Message 'A caller''s $VerbosePreference reaches the module, so the command line is printed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same function, with -Verbose:$false on the call it makes
$fake = New-FakeGitHubCli -Output @('{"id":"abc123"}')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller { Get-GitHubGist -Id 'abc123' -Verbose:$false }
        })

    # Assert
    Assert-Equal -Expected @() -Actual $lines -Message '-Verbose:$false prints nothing, whatever the caller prefers'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a creation from a function whose scope sets $VerbosePreference
$fake = New-FakeGitHubCli -Output @('{"id":"abc123","html_url":"https://gist.github.com/me/abc123"}')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller { New-GitHubGist -Content 'A' -FileName 'a.txt' }
        })

    # Assert
    $expected = @(
        'Calling gists with POST'
        'Calling gists: gh api gists --method POST --input - (with standard input)'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'A function that makes its call through the gist helper follows the caller too, never showing the body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
