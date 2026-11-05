#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubReleasesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubReleaseAsset -Tag 'v1.0.0' -Name 'a.zip' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'delete-asset', '--yes', '--repo', 'o/r', '--', 'v1.0.0', 'a.zip') `
        -Actual $call.Arguments `
        -Message 'The asset is deleted without prompting, and the tag and name come last, after a --'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - asset names from the pipeline, one that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act
    @('a.zip', '-b.zip') | Remove-GitHubReleaseAsset -Tag 'v1'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped asset is deleted in its own call'
    Assert-Equal `
        -Expected @('release', 'delete-asset', '--yes', '--', 'v1', '-b.zip') `
        -Actual $calls[1].Arguments `
        -Message 'An asset name that looks like an option is still a name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release's Assets piped in, with the release itself as -Tag
$release = [PSCustomObject]@{
    TagName    = 'v1'
    Repository = 'other/repo'
    Assets     = @(
        [PSCustomObject]@{ Name = 'a.zip'; Size = 10 }
        [PSCustomObject]@{ Name = 'b.zip'; Size = 20 }
    )
}
$fake = New-FakeGitHubCli
try {
    # Act
    $release.Assets | Remove-GitHubReleaseAsset -Tag $release
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped asset object is deleted in its own call'
    Assert-Equal `
        -Expected @('release', 'delete-asset', '--yes', '--repo', 'other/repo', '--', 'v1', 'b.zip') `
        -Actual $calls[1].Arguments `
        -Message 'by its Name, from the release''s tag in the repository the release came from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - assets as hashtables, one holding a Keys entry, and a name that is a number
$fake = New-FakeGitHubCli
try {
    # Act
    @(@{ name = 'c.zip' }, @{ Name = 'd.zip'; Keys = 'x' }, 7) | Remove-GitHubReleaseAsset -Tag 'v1'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('c.zip', 'd.zip', '7') `
        -Actual @($calls[0].Arguments[-1], $calls[1].Arguments[-1], $calls[2].Arguments[-1]) `
        -Message 'A hashtable is read by its Name key, in any case, whatever else it holds; a number is a name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release piped in where its assets were meant
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ TagName = 'v1'; Name = 'Release One' } | Remove-GitHubReleaseAsset -Tag 'v1'
    } -MessageLike 'A release was given as the asset: pipe its Assets instead, and give the release as -Tag.' `
        -Message 'A release is not deleted as an asset named after its title'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names that name no asset
$refusals = @(
    @{
        Name    = '  '
        Like    = "'  ' is not an asset: give its file name, or an asset object."
        Message = 'A blank name is refused'
    }
    @{
        Name    = [PSCustomObject]@{ Size = 1 }
        Like    = 'An asset object needs a Name, and this one has none: PSCustomObject.'
        Message = 'An object without a Name is refused, not sent as its text'
    }
    @{
        Name    = @('a.zip', 'b.zip')
        Like    = 'Give one asset at a time, not a list of 2; pipe them to name several.'
        Message = 'Several names in one argument are refused'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($refusal in $refusals) {
        Assert-Throws -ScriptBlock {
            Remove-GitHubReleaseAsset -Tag 'v1' -Name $refusal.Name
        } -MessageLike $refusal.Like -Message $refusal.Message
    }

    Assert-Throws -ScriptBlock {
        Remove-GitHubReleaseAsset -Tag 'v1' -Name 'a.zip' -Repository $null
    } -MessageLike "-Repository was given, but it is `$null - leave it out to use the current directory's repository." `
        -Message 'A -Repository given as $null is refused, not taken for the current one'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release from another repository given as -Tag, with a name
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubReleaseAsset -Tag ([PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }) -Name 'a.zip'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'delete-asset', '--yes', '--repo', 'a/b', '--', 'v1', 'a.zip') `
        -Actual $call.Arguments `
        -Message 'The asset is deleted from the release in the repository the release came from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with -Repository
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubReleaseAsset -Tag 'v1.0.0' -Name 'a.zip' -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Delete asset" on target "o/r release v1.0.0 asset a.zip".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages -Message '-WhatIf names the asset and its release'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two assets piped in, one a name and one an object
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        @('a.zip', [PSCustomObject]@{ Name = 'b.zip' }) | Remove-GitHubReleaseAsset -Tag 'v1' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete asset" on target "release v1 asset a.zip".'
        'What if: Performing the operation "Delete asset" on target "release v1 asset b.zip".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped asset is named on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is deleted'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a release piped in as the asset
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ TagName = 'v1'; Name = 'One' } | Remove-GitHubReleaseAsset -Tag 'v1' -WhatIf
    } -MessageLike 'A release was given as the asset: pipe its Assets instead, and give the release as -Tag.' `
        -Message 'A release given as the asset is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
