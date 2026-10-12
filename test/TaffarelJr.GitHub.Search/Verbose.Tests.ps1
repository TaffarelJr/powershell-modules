#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$env:GH_HOST = $null
$fields = 'assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isLocked,isPullRequest,' +
'labels,number,repository,state,title,updatedAt,url'
$commandLine = "Searching issues: gh search issues --json $fields --repo o/r -- crash"

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a search with its own -Verbose
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $lines = @(Get-VerboseLine { Find-GitHubIssue -Query 'crash' -Repository 'o/r' -Verbose })

    # Assert
    Assert-Equal -Expected @($commandLine) -Actual $lines `
        -Message 'A call with -Verbose prints the gh command line, once'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the search from a function whose scope sets $VerbosePreference
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller { Find-GitHubIssue -Query 'crash' -Repository 'o/r' }
        })

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
            Invoke-VerboseCaller {
                Find-GitHubIssue -Query 'crash' -Repository 'o/r' -Verbose:$false
            }
        })

    # Assert
    Assert-Equal -Expected @() -Actual $lines -Message '-Verbose:$false prints nothing, whatever the caller prefers'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
