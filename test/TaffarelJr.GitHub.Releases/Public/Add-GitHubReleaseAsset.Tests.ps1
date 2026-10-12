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
# Arrange - several files in one upload
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubReleaseAsset -Tag 'v1.0.0' -Path @('a.zip', './dist/*.nupkg#Package') -Clobber -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('release', 'upload', '--clobber', '--repo', 'o/r', '--', 'v1.0.0', 'a.zip', './dist/*.nupkg#Package')
    Assert-Equal `
        -Expected $expected `
        -Actual $call.Arguments `
        -Message '-Path reaches gh as given, for gh to expand, after the tag and a --'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files from the pipeline, one that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act
    @('a.zip', '-b.zip') | Add-GitHubReleaseAsset -Tag 'v1'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'The piped files are uploaded in one call'
    Assert-Equal `
        -Expected @('release', 'upload', '--', 'v1', 'a.zip', '-b.zip') `
        -Actual $calls[0].Arguments `
        -Message 'in the order they came, a file that looks like an option still a file'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - five files from the pipeline, with -Clobber
$fake = New-FakeGitHubCli
try {
    # Act
    'a.zip', 'b.zip', 'c.zip', 'd.zip', 'e.zip' | Add-GitHubReleaseAsset -Tag 'v1' -Clobber -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'Five piped files make one gh call, not five'
    Assert-Equal `
        -Expected @('release', 'upload', '--clobber', '--repo', 'o/r', '--', 'v1', 'a.zip', 'b.zip', 'c.zip', 'd.zip',
            'e.zip') `
        -Actual $calls[0].Arguments `
        -Message 'holding every file, after one tag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text carrying a Repository property, which binds -Repository for each path piped in
$inRepository = {
    param($Text, $Repository)
    $Text | Add-Member -NotePropertyName Repository -NotePropertyValue $Repository -PassThru
}
$mixed = @(
    @{
        Piped   = @((& $inRepository 'a.zip' 'a/b'), (& $inRepository 'b.zip' 'c/d'))
        Like    = 'The files piped in are for more than one release: a/b release v1, then c/d release v1.*'
        Message = 'Paths for two repositories are refused, naming both'
    }
    @{
        Piped   = @((& $inRepository 'a.zip' 'a/b'), 'b.zip')
        Like    = 'The files piped in are for more than one release: a/b release v1, then release v1.*'
        Message = 'as are paths for a repository and for the current directory''s'
    }
)
foreach ($case in $mixed) {
    $fake = New-FakeGitHubCli
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            $case.Piped | Add-GitHubReleaseAsset -Tag 'v1'
        } -MessageLike $case.Like -Message $case.Message
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is uploaded'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - paths that name one repository in two spellings
$fake = New-FakeGitHubCli
try {
    $piped = @((& $inRepository 'a.zip' 'a/b'), (& $inRepository 'b.zip' 'https://github.com/A/B.git'))

    # Act
    $piped | Add-GitHubReleaseAsset -Tag 'v1'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'The same repository written two ways is one release'
    Assert-Equal `
        -Expected @('release', 'upload', '--repo', 'a/b', '--', 'v1', 'a.zip', 'b.zip') `
        -Actual $calls[0].Arguments `
        -Message 'uploaded to in the repository the first file named'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing in the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @() | Add-GitHubReleaseAsset -Tag 'v1'

    # Assert
    Assert-Equal `
        -Expected 0 `
        -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'An empty pipeline uploads nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - calls that are refused before gh
$refusals = @(
    @{
        Call    = { Add-GitHubReleaseAsset -Tag 'v1' -Path 'a.zip', ' ' }
        Like    = "Cannot validate argument on parameter 'Path'." +
        ' -Path holds a blank path: give the path of each file, or leave it out.'
        Message = 'A blank path is refused, not sent to gh as a file'
    }
    @{
        Call    = { Add-GitHubReleaseAsset -Tag 'v1' -LiteralPath ' ' }
        Like    = '*-LiteralPath holds a blank path: give the path of each file, or leave it out.'
        Message = 'as is a blank literal path'
    }
    @{
        Call    = { [PSCustomObject]@{ TagName = 'v1.0.0'; Name = 'Release One' } | Add-GitHubReleaseAsset -Tag 'v1' }
        Like    = 'A PSCustomObject was piped in, which is not a file: pipe paths as text, or files from Get-ChildItem.'
        Message = 'An object that is not a file is refused, not uploaded as its text'
    }
    @{
        Call    = { Add-GitHubReleaseAsset -Tag 'v1', 'v2' -Path 'a.zip' }
        Like    = 'Give one release at a time, not a list of 2; call once per release.'
        Message = 'Several releases are refused, with advice that fits a -Tag not taking pipeline input'
    }
    @{
        Call    = { Add-GitHubReleaseAsset -Tag 'v1' -Path 'a.zip' -Repository $null }
        Like    = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message = 'A -Repository given as $null is refused, not taken for the current one'
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

$folder = New-ReleaseTestFolder -File 'one.txt', 'a[1].zip', 'C#/b.zip'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files piped in from Get-ChildItem, one with a name gh would read as a pattern
    $fake = New-FakeGitHubCli
    try {
        # Act
        Get-ChildItem -LiteralPath $folder -File | Add-GitHubReleaseAsset -Tag 'v1'
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        $expected = @(
            'release', 'upload', '--', 'v1', "$(Join-Path $folder 'a[1].zip')#", "$(Join-Path $folder 'one.txt')#"
        )
        Assert-Equal -Expected 1 -Actual $calls.Count -Message 'The files piped in are uploaded in one call'
        Assert-Equal `
            -Expected $expected `
            -Actual $calls[0].Arguments `
            -Message 'each by its full path, ended with a bare # so gh takes it literally'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a literal path in a folder whose name holds a #, from inside it
    $fake = New-FakeGitHubCli
    try {
        # Act
        $files = @((Join-Path $folder 'C#' 'b.zip'), (Join-Path $folder 'one.txt'))
        Push-Location -LiteralPath (Join-Path $folder 'C#')
        try {
            Add-GitHubReleaseAsset -Tag 'v1' -LiteralPath $files
        }
        finally {
            Pop-Location
        }

        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        Assert-Equal `
            -Expected @('release', 'upload', '--', 'v1', 'b.zip#', "$(Join-Path $folder 'one.txt')#") `
            -Actual $call.Arguments `
            -Message 'A path holding a # is sent relative to the location, and the rest in full'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a literal path that is a folder
    $fake = New-FakeGitHubCli
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Add-GitHubReleaseAsset -Tag 'v1' -LiteralPath $folder
        } -MessageLike "-LiteralPath '*' is not a file." `
            -Message 'A folder is refused before gh sees it, naming the parameter'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the release given as an object from another repository
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubReleaseAsset -Tag ([PSCustomObject]@{ TagName = 'v1'; Repository = 'other/repo' }) -Path 'a.zip'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'upload', '--repo', 'other/repo', '--', 'v1', 'a.zip') `
        -Actual $call.Arguments `
        -Message 'The files go to the release in the repository it came from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with several paths and -Clobber
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubReleaseAsset -Tag 'v1.0.0' -Path @('a.zip', './dist/*.nupkg') -Clobber -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Upload a.zip, ./dist/*.nupkg, replacing assets of the same name"' +
    ' on target "o/r release v1.0.0".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages -Message '-WhatIf names the release and the files'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$folder = New-ReleaseTestFolder -File 'a.zip', 'b.zip'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -WhatIf with two files piped in, for a release from another repository
    $fake = New-FakeGitHubCli
    try {
        # Act
        $release = [PSCustomObject]@{ TagName = 'v1'; Repository = 'other/repo' }
        $result = Get-WhatIfOutput -ScriptBlock {
            Get-ChildItem -LiteralPath $folder -File | Add-GitHubReleaseAsset -Tag $release -WhatIf
        }

        # Assert
        $files = "$(Join-Path $folder 'a.zip'), $(Join-Path $folder 'b.zip')"
        $expected = "What if: Performing the operation `"Upload $files`" on target `"other/repo release v1`"."
        Assert-Equal -Expected @($expected) -Actual $result.Messages `
            -Message 'The piped files are named together, for the release in the repository it came from'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is uploaded'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -WhatIf with a literal path that is a folder
    $fake = New-FakeGitHubCli
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Add-GitHubReleaseAsset -Tag 'v1' -LiteralPath $folder -WhatIf
        } -MessageLike "-LiteralPath '*' is not a file." `
            -Message 'A folder is still refused under -WhatIf'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
