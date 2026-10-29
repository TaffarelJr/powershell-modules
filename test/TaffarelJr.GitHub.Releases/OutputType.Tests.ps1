#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each command that returns objects, called through the fake gh: what it really returns is what its
# [OutputType()] names
$url = 'https://github.com/o/r/releases/tag/v1'
$release = "{`"tagName`":`"v1`",`"url`":`"$url`"}"
$returning = @(
    @{
        Command  = 'Get-GitHubRelease'
        Answer   = $release
        Block    = { Get-GitHubRelease -Tag 'v1' -Repository 'o/r' }
        Declared = [PSCustomObject]
        Runtime  = 'System.Management.Automation.PSCustomObject'
        Name     = 'Get-GitHubRelease, for one release'
    }
    @{
        Command  = 'Get-GitHubRelease'
        Answer   = "[$release]"
        Block    = { Get-GitHubRelease -List -Repository 'o/r' }
        Declared = [PSCustomObject]
        Runtime  = 'System.Management.Automation.PSCustomObject'
        Name     = 'Get-GitHubRelease, for a listing'
    }
    @{
        Command  = 'New-GitHubRelease'
        Answer   = $url
        Block    = { New-GitHubRelease -Tag 'v1' -Repository 'o/r' }
        Declared = [string]
        Runtime  = 'System.String'
        Name     = 'New-GitHubRelease'
    }
    @{
        Command  = 'Set-GitHubRelease'
        Answer   = $url
        Block    = { Set-GitHubRelease -Tag 'v1' -Title 'x' -Repository 'o/r' }
        Declared = [string]
        Runtime  = 'System.String'
        Name     = 'Set-GitHubRelease'
    }
)
foreach ($case in $returning) {
    $fake = New-FakeGitHubCli -Output $case.Answer
    try {
        # Act
        $result = @(& $case.Block)
        $declared = @((Get-Command -Name $case.Command).OutputType.Type)

        # Assert
        Assert-Equal -Expected 1 -Actual $result.Count -Message "$($case.Name) returns one object"
        Assert-Equal -Expected $case.Runtime -Actual $result[0].GetType().FullName `
            -Message "$($case.Name) returns a $($case.Runtime)"
        Assert-That -Condition ($case.Declared -in $declared) `
            -Message "$($case.Name) declares [OutputType($($case.Declared.Name))]"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each command that returns nothing, called through a fake gh that prints a line, as gh does
$silent = @(
    @{ Command = 'Add-GitHubReleaseAsset'; Block = { Add-GitHubReleaseAsset 'v1' 'a.zip' -Repository 'o/r' } }
    @{ Command = 'Remove-GitHubRelease'; Block = { Remove-GitHubRelease -Tag 'v1' -Repository 'o/r' } }
    @{ Command = 'Remove-GitHubReleaseAsset'; Block = { Remove-GitHubReleaseAsset -Tag 'v1' -Name 'a.zip' } }
    @{ Command = 'Save-GitHubReleaseAsset'; Block = { Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.zip' } }
)
foreach ($case in $silent) {
    $fake = New-FakeGitHubCli -Output 'done'
    try {
        # Act
        $result = @(& $case.Block)
        $declared = @((Get-Command -Name $case.Command).OutputType)

        # Assert
        Assert-Equal -Expected 0 -Actual $result.Count -Message "$($case.Command) returns nothing"
        Assert-Equal -Expected 0 -Actual $declared.Count -Message "$($case.Command) declares no [OutputType()]"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
