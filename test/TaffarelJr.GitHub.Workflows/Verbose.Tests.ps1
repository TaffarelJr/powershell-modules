#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$commandLine = 'Listing workflows: gh workflow list --json id,name,path,state --repo o/r'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a read with its own -Verbose
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $lines = @(Get-VerboseLine { Get-GitHubWorkflow -Repository 'o/r' -Verbose })

    # Assert
    Assert-Equal -Expected @($commandLine) -Actual $lines `
        -Message 'A call with -Verbose prints the gh command line, once'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the read from a function whose scope sets $VerbosePreference
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $lines = @(Get-VerboseLine { Invoke-VerboseCaller { Get-GitHubWorkflow -Repository 'o/r' } })

    # Assert
    Assert-Equal -Expected @($commandLine) -Actual $lines `
        -Message 'A caller''s $VerbosePreference reaches the module, so the command line is printed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same function, with -Verbose:$false on the call it makes
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller { Get-GitHubWorkflow -Repository 'o/r' -Verbose:$false }
        })

    # Assert
    Assert-Equal -Expected @() -Actual $lines -Message '-Verbose:$false prints nothing, whatever the caller prefers'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
