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

$folder = New-ReleaseTestFolder
$elsewhere = New-ReleaseTestFolder
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - every asset of one release into a relative folder
    $fake = New-FakeGitHubCli
    try {
        # Act
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            Save-GitHubReleaseAsset -Tag 'v1.0.0' -Destination 'out' -Clobber -Repository 'o/r'
        }
        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        $expected = @(
            'release', 'download', '--dir', (Join-Path $folder 'out'), '--clobber', '--repo', 'o/r', '--', 'v1.0.0'
        )
        Assert-Equal `
            -Expected $expected `
            -Actual $call.Arguments `
            -Message 'The folder is resolved against PowerShell''s location, and the tag comes last, after a --'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the latest release's source archive to a relative file
    $fake = New-FakeGitHubCli
    try {
        # Act
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            Save-GitHubReleaseAsset -Archive zip -Output 'one.zip' -SkipExisting
        }
        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        $expected = @(
            'release', 'download', '--archive', 'zip', '--output', (Join-Path $folder 'one.zip'), '--skip-existing'
        )
        Assert-Equal `
            -Expected $expected `
            -Actual $call.Arguments `
            -Message 'Without -Tag the latest release is used, and the file is resolved against PowerShell''s location'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}
finally {
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - matching assets, one pattern that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubReleaseAsset -Tag 'v1' -Pattern @('*.nupkg', '--')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'download', '--pattern=*.nupkg', '--pattern=--', '--', 'v1') `
        -Actual $call.Arguments `
        -Message 'One --pattern per pattern, each the value of its flag whatever it holds'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a tag that looks like an option, and an output file that starts with a dash
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubReleaseAsset -Tag '--web' -Output '-odd.bin'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $output = Join-Path (Get-Location).ProviderPath '-odd.bin'
    Assert-Equal `
        -Expected @('release', 'download', '--output', $output, '--', '--web') `
        -Actual $call.Arguments `
        -Message 'A tag is an operand whatever it starts with, and a file name is a full path'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - releases piped in, from another repository and as text
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }, 'v2') | Save-GitHubReleaseAsset -Pattern '*.zip'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('release', 'download', '--pattern=*.zip', '--repo', 'a/b', '--', 'v1') `
        -Actual $calls[0].Arguments `
        -Message 'A release piped in is downloaded from the repository it came from'
    Assert-Equal `
        -Expected @('release', 'download', '--pattern=*.zip', '--', 'v2') `
        -Actual $calls[1].Arguments `
        -Message 'and a tag piped in as text from the current one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release given as -Tag, not piped, from another repository
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubReleaseAsset -Tag ([PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }) -Archive zip
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'download', '--archive', 'zip', '--repo', 'a/b', '--', 'v1') `
        -Actual $call.Arguments `
        -Message 'A release given by name is downloaded from the repository it came from too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every valid combination of the options: what to download, where, and over what
$here = (Get-Location).ProviderPath
$whats = @(
    @{ Parameters = @{}; Arguments = @() }
    @{ Parameters = @{ Pattern = '*.zip' }; Arguments = @('--pattern=*.zip') }
    @{ Parameters = @{ Archive = 'TAR.GZ' }; Arguments = @('--archive', 'tar.gz') }
)
$wheres = @(
    @{ Parameters = @{}; Arguments = @() }
    @{ Parameters = @{ Destination = 'out' }; Arguments = @('--dir', (Join-Path $here 'out')) }
    @{ Parameters = @{ Output = 'f.zip' }; Arguments = @('--output', (Join-Path $here 'f.zip')) }
)
$overs = @(
    @{ Parameters = @{}; Arguments = @() }
    @{ Parameters = @{ Clobber = $true }; Arguments = @('--clobber') }
    @{ Parameters = @{ SkipExisting = $true }; Arguments = @('--skip-existing') }
    @{ Parameters = @{ Clobber = $false; SkipExisting = $true }; Arguments = @('--skip-existing') }
)
$combinations = foreach ($what in $whats) {
    foreach ($where in $wheres) {
        foreach ($over in $overs) {
            $parameters = $what.Parameters + $where.Parameters + $over.Parameters
            $options = $what.Arguments + $where.Arguments + $over.Arguments
            @{
                Parameters = $parameters
                Arguments  = @('release', 'download') + $options + @('--', 'v1')
                Name       = ($parameters.PSBase.Keys | Sort-Object) -join ','
            }
        }
    }
}
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($combination in $combinations) {
        $parameters = $combination.Parameters
        'v1' | Save-GitHubReleaseAsset @parameters
        Assert-Equal `
            -Expected $combination.Arguments `
            -Actual @(Get-FakeGitHubCall -Fixture $fake)[-1].Arguments `
            -Message "A piped tag binds with {$($combination.Name)}, an archive type lower-cased"
    }

    foreach ($combination in $combinations) {
        $parameters = $combination.Parameters
        Save-GitHubReleaseAsset -Tag 'v1' @parameters
        Assert-Equal `
            -Expected $combination.Arguments `
            -Actual @(Get-FakeGitHubCall -Fixture $fake)[-1].Arguments `
            -Message "and so does a tag given by name with {$($combination.Name)}"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - calls that are refused before gh
$refusals = @(
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Output '-' }
        Like    = "*'-' would have gh write the asset to standard output*give a file name."
        Message = 'An output of one dash is refused, as the asset would be discarded'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag '' }
        Like    = "'' is not a release tag*"
        Message = 'An empty -Tag is refused, not taken for the latest release'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.zip', '' }
        Like    = '*-Pattern holds a blank pattern: give glob patterns, or leave it out.'
        Message = 'An empty pattern is refused'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Pattern @() }
        Like    = '-Pattern was given no patterns, so every asset would be downloaded.' +
        ' Give a pattern, or leave -Pattern off.'
        Message = 'A -Pattern holding no pattern, as from a filter that matched nothing, is refused, not widened'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Pattern @() }
        Like    = '-Pattern was given no patterns, so every asset would be downloaded.*'
        Message = 'and without -Tag, it is the empty -Pattern that is named, not a missing one'
    }
    @{
        Call    = { 'v1' | Save-GitHubReleaseAsset -Pattern @() }
        Like    = '-Pattern was given no patterns, so every asset would be downloaded.*'
        Message = 'as with a tag piped in'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Destination ' ' }
        Like    = "Cannot validate argument on parameter 'Destination'." +
        ' -Destination is blank: give a folder, or leave it out.'
        Message = 'A blank folder is refused, so no folder named with spaces is made'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Output '' }
        Like    = '-Output is blank: give a file name, or leave it out.'
        Message = 'An empty output file is refused'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Output ' ' }
        Like    = '-Output is blank: give a file name, or leave it out.'
        Message = 'as is a blank one'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Destination 'Env:\TEMP' }
        Like    = '*is not a file system path*'
        Message = 'A folder that is not on the file system is refused'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Tag 'v1' -Repository $null }
        Like    = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message = 'A -Repository given as $null is refused, not taken for the current one'
    }
    @{
        Call    = { Save-GitHubReleaseAsset -Destination 'out' -SkipExisting }
        Like    = '-Tag was left out, which means the latest release, and gh then needs -Pattern or -Archive*'
        Message = 'The latest release with neither -Pattern nor -Archive is refused, as gh would refuse it'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($refusal in $refusals) {
        Assert-Throws -ScriptBlock $refusal.Call -MessageLike $refusal.Like -Message $refusal.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - options that exclude each other, given by name and with a tag piped in
$pairs = @(
    @{
        Parameters = @{ Pattern = '*.zip'; Archive = 'zip' }
        Like       = '-Pattern and -Archive cannot be used together: *. Give only one.'
        Message    = '-Pattern with -Archive is refused, naming the pair'
    }
    @{
        Parameters = @{ Destination = 'out'; Output = 'a.zip' }
        Like       = '-Destination and -Output cannot be used together: *. Give only one.'
        Message    = '-Destination with -Output is refused, naming the pair'
    }
    @{
        Parameters = @{ Clobber = $true; SkipExisting = $true }
        Like       = '-Clobber and -SkipExisting cannot be used together: *. Give only one.'
        Message    = '-Clobber with -SkipExisting is refused, naming the pair'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($pair in $pairs) {
        $parameters = $pair.Parameters
        Assert-Throws -ScriptBlock {
            Save-GitHubReleaseAsset -Tag 'v1' @parameters
        } -MessageLike $pair.Like -Message $pair.Message
        Assert-Throws -ScriptBlock {
            'v1' | Save-GitHubReleaseAsset @parameters
        } -MessageLike $pair.Like -Message "$($pair.Message), with a tag piped in too"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$folder = New-ReleaseTestFolder
$elsewhere = New-ReleaseTestFolder
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -WhatIf with patterns into a relative folder, overwriting
    $fake = New-FakeGitHubCli
    try {
        # Act
        $result = Get-WhatIfOutput -ScriptBlock {
            Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
                Save-GitHubReleaseAsset -Tag 'v1.0.0' -Pattern '*.zip', '*.nupkg' -Destination 'out' -Clobber `
                    -Repository 'o/r' `
                    -WhatIf
            }
        }

        # Assert
        $expected = 'What if: Performing the operation "Download the assets matching *.zip, *.nupkg of o/r release' +
        " v1.0.0, overwriting files that exist`" on target `"$(Join-Path $folder 'out')`"."
        Assert-Equal -Expected @($expected) -Actual $result.Messages `
            -Message '-WhatIf names the folder it would write to, resolved against PowerShell''s location'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
        Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
        Assert-Equal -Expected @() -Actual @(Get-ChildItem -LiteralPath $folder -Force) `
            -Message 'and nothing is written'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -WhatIf with the latest release's source archive to a relative file
    $fake = New-FakeGitHubCli
    try {
        # Act
        $result = Get-WhatIfOutput -ScriptBlock {
            Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
                Save-GitHubReleaseAsset -Archive zip -Output 'one.zip' -SkipExisting -Repository 'o/r' -WhatIf
            }
        }

        # Assert
        $expected = 'What if: Performing the operation "Download the zip source archive of the latest release of' +
        " o/r, skipping files that exist`" on target `"$(Join-Path $folder 'one.zip')`"."
        Assert-Equal -Expected @($expected) -Actual $result.Messages -Message '-WhatIf names the file it would write'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -WhatIf with two releases piped in, into the current location
    $fake = New-FakeGitHubCli
    try {
        # Act
        $result = Get-WhatIfOutput -ScriptBlock {
            Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
                @('v1', [PSCustomObject]@{ TagName = 'v2'; Repository = 'other/repo' }) |
                    Save-GitHubReleaseAsset -WhatIf
            }
        }

        # Assert
        $expected = @(
            "What if: Performing the operation `"Download every asset of release v1`" on target `"$folder`"."
            "What if: Performing the operation `"Download every asset of other/repo release v2`" on target `"$folder`"."
        )
        Assert-Equal -Expected $expected -Actual $result.Messages `
            -Message 'Each piped release is named on its own, and the target is PowerShell''s location'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is downloaded'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}
finally {
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with -Pattern and -Archive together
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.zip' -Archive zip -WhatIf
    } -MessageLike '-Pattern and -Archive cannot be used together: *. Give only one.' `
        -Message 'The pair is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf for the latest release of a repository given as a URL with a credential
$fake = New-FakeGitHubCli
$output = Join-Path ([IO.Path]::GetTempPath()) 'source.zip'
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Save-GitHubReleaseAsset -Archive zip -Output $output `
            -Repository 'https://user:SENTINEL@ghe.example.com/o/r' `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Download the zip source archive of the latest release of' +
    " ghe.example.com/o/r`" on target `"$output`"."
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message 'The repository is named HOST/OWNER/REPO, without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
