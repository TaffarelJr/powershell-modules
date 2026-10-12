#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$fields = 'apiUrl,assets,author,body,createdAt,databaseId,id,isDraft,isImmutable,isPrerelease,name,' +
'publishedAt,tagName,tarballUrl,targetCommitish,uploadUrl,url,zipballUrl'
$commandLine = "Reading release v1: gh release view --json $fields --repo o/r -- v1"

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a read with its own -Verbose
$fake = New-FakeGitHubCli -Output @('{"tagName":"v1"}')
try {
    # Act
    $lines = @(Get-VerboseLine { Get-GitHubRelease -Tag 'v1' -Repository 'o/r' -Verbose })

    # Assert
    Assert-Equal -Expected @($commandLine) -Actual $lines `
        -Message 'A call with -Verbose prints the gh command line, once'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the read from a function whose scope sets $VerbosePreference
$fake = New-FakeGitHubCli -Output @('{"tagName":"v1"}')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller { Get-GitHubRelease -Tag 'v1' -Repository 'o/r' }
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
$fake = New-FakeGitHubCli -Output @('{"tagName":"v1"}')
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller { Get-GitHubRelease -Tag 'v1' -Repository 'o/r' -Verbose:$false }
        })

    # Assert
    Assert-Equal -Expected @() -Actual $lines -Message '-Verbose:$false prints nothing, whatever the caller prefers'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an edit and a creation from a function whose scope sets $VerbosePreference
$fake = New-FakeGitHubCli
try {
    # Act
    $lines = @(Get-VerboseLine {
            Invoke-VerboseCaller {
                Set-GitHubRelease -Tag 'v1' -Title 'One' -Repository 'o/r'
                New-GitHubRelease -Tag 'v2' -Repository 'o/r'
            }
        })

    # Assert
    $expected = @(
        'Editing release v1: gh release edit --title=One --repo o/r -- v1'
        'Creating release v2: gh release create --repo o/r -- v2'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'Functions that change a release through the shared helper follow the caller too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
