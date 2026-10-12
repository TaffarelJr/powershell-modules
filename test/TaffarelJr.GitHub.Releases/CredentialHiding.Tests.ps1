#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the tables hand to Assert-Throws and Get-WhatIfOutput, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubReleasesTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case. A path that differs by platform keeps a wildcard for the
# part before the credential, and its case checks for SENTINEL on its own.
$url = 'https://user:SENTINEL@ghe.example.com/o/r'
$shown = 'https://***@ghe.example.com/o/r'
$separator = [IO.Path]::DirectorySeparatorChar
$escape = { param([string]$Text) [WildcardPattern]::Escape($Text) }
$listed = [PSCustomObject]@{ TagName = $url; Repository = $url }

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every -WhatIf line that names a tag, an asset, a pattern, or a repository it was given
$fake = New-FakeGitHubCli
$output = Join-Path ([IO.Path]::GetTempPath()) 'source.zip'
$previews = @(
    @{
        Block    = { Remove-GitHubRelease -Tag $url -Repository 'o/r' -WhatIf }
        Expected = "What if: Performing the operation `"Delete release`" on target `"o/r release $shown`"."
        Name     = 'Remove-GitHubRelease names the tag without its credential'
    }
    @{
        Block    = { Set-GitHubRelease -Tag $url -Draft:$false -Repository $url -WhatIf }
        Expected = "What if: Performing the operation `"Edit release`"" +
        " on target `"ghe.example.com/o/r release $shown`"."
        Name     = 'Set-GitHubRelease names the tag and the repository without their credentials'
    }
    @{
        Block    = { New-GitHubRelease -Tag $url -Asset "$url/a.zip", 'b.zip' -Repository 'o/r' -WhatIf }
        Expected = "What if: Performing the operation `"Create release, uploading $shown/a.zip, b.zip`"" +
        " on target `"o/r release $shown`"."
        Name     = 'New-GitHubRelease names the tag and each asset without a credential'
    }
    @{
        Block    = { Add-GitHubReleaseAsset -Tag $url -Path "$url/a.zip", 'b.zip' -Clobber -Repository 'o/r' -WhatIf }
        Expected = "What if: Performing the operation `"Upload $shown/a.zip, b.zip, replacing assets of the same" +
        " name`" on target `"o/r release $shown`"."
        Name     = 'Add-GitHubReleaseAsset names the tag and each path without a credential'
    }
    @{
        Block    = { Remove-GitHubReleaseAsset -Tag $url -Name $url -Repository 'o/r' -WhatIf }
        Expected = "What if: Performing the operation `"Delete asset`" on target `"o/r release $shown asset $shown`"."
        Name     = 'Remove-GitHubReleaseAsset names the tag and the asset without a credential'
    }
    @{
        Block    = {
            Save-GitHubReleaseAsset -Tag $url -Pattern $url, '*.zip' -Output $output -Repository 'o/r' -WhatIf
        }
        Expected = "What if: Performing the operation `"Download the assets matching $shown, *.zip of o/r release" +
        " $shown`" on target `"$output`"."
        Name     = 'Save-GitHubReleaseAsset names the tag and each pattern without a credential'
    }
)

try {
    foreach ($case in $previews) {
        # Act
        $run = Get-WhatIfOutput -ScriptBlock $case.Block

        # Assert
        Assert-Equal -Expected @($case.Expected) -Actual $run.Messages -Message $case.Name
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files whose names hold a credential, one reached by a relative path
$folder = New-ReleaseTestFolder -File 'SENTINEL@h.example/a.zip', 'x SENTINEL@h.example/c#.zip'
$fake = New-FakeGitHubCli
try {
    Push-Location -LiteralPath $folder
    try {
        # Act
        $run = Get-WhatIfOutput -ScriptBlock {
            New-GitHubRelease -Tag 'v1' -Asset 'b.zip' -LiteralAsset 'SENTINEL@h.example/a.zip' -WhatIf
        }
    }
    finally {
        Pop-Location
    }

    # Assert
    $expected = 'What if: Performing the operation "Create release, uploading b.zip, ***@h.example/a.zip"' +
    ' on target "release v1".'
    Assert-Equal -Expected @($expected) -Actual $run.Messages `
        -Message 'New-GitHubRelease names a literal asset without its credential'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file whose path holds a credential and a #, which no relative path avoids
    $refused = Join-Path $folder 'x SENTINEL@h.example' 'c#.zip'
    $tail = "***@h.example$($separator)c#.zip' holds a '#', which gh reads as the start of a label, and so does" +
    ' its path from the current location. Rename or copy the file, or run from inside the folder whose name' +
    " holds the '#'."
    $pattern = (& $escape "-LiteralAsset '") + '*' + (& $escape $tail)

    # Act / Assert
    Assert-Throws -ScriptBlock { New-GitHubRelease -Tag 'v1' -LiteralAsset $refused } -MessageLike $pattern `
        -Message 'A literal asset refused for its # is named without the credential in its path'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a destination below a folder whose name holds a credential
$fake = New-FakeGitHubCli
try {
    # Act
    $run = Get-WhatIfOutput -ScriptBlock {
        Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.zip' -Destination 'x SENTINEL@h.example/out' -WhatIf
    }

    # Assert
    $message = $run.Messages -join "`n"
    $head = 'What if: Performing the operation "Download the assets matching *.zip of release v1" on target "'
    $pattern = (& $escape $head) + '*' + (& $escape "***@h.example$($separator)out`".")
    Assert-Equal -Expected $true -Actual ($message -like $pattern) `
        -Message 'Save-GitHubReleaseAsset names the destination without the credential in its path'
    Assert-Equal -Expected $false -Actual $message.Contains('SENTINEL') -Message 'and nothing of it is left'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every message that shows a value it was given, with no gh run
$messages = @(
    @{
        Block    = { Remove-GitHubRelease -Tag $listed -Repository 'o/other' }
        Expected = "Release $shown is in ghe.example.com/o/r, but -Repository names o/other: give one or the other."
        Name     = 'A release in another repository than -Repository names its tag without a credential'
    }
    @{
        Block    = { New-GitHubRelease -Tag 'v1' -Repository "$url x" }
        Expected = "'$shown x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
        Name     = 'New-GitHubRelease shows a -Repository that is no repository without its credential'
    }
    @{
        Block    = { Get-GitHubRelease -Repository "$url x" }
        Expected = "'$shown x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
        Name     = 'Get-GitHubRelease shows a -Repository that is no repository without its credential'
    }
    @{
        Block    = { New-GitHubRelease -Tag 'v1' -NotesFile 'SENTINEL@ghe.example.com/notes.md' }
        Expected = "-NotesFile '***@ghe.example.com/notes.md' is not a file."
        Name     = 'New-GitHubRelease shows a -NotesFile that is no file without its credential'
    }
    @{
        Block    = { Set-GitHubRelease -Tag 'v1' -NotesFile 'SENTINEL@ghe.example.com/notes.md' }
        Expected = "-NotesFile '***@ghe.example.com/notes.md' is not a file."
        Name     = 'Set-GitHubRelease shows a -NotesFile that is no file without its credential'
    }
    @{
        Block    = { New-GitHubRelease -Tag 'v1' -LiteralAsset 'SENTINEL@ghe.example.com/a.zip' }
        Expected = "-LiteralAsset '***@ghe.example.com/a.zip' is not a file."
        Name     = 'New-GitHubRelease shows a -LiteralAsset that is no file without its credential'
    }
    @{
        Block    = { Add-GitHubReleaseAsset -Tag 'v1' -LiteralPath 'SENTINEL@ghe.example.com/a.zip' }
        Expected = "-LiteralPath '***@ghe.example.com/a.zip' is not a file."
        Name     = 'Add-GitHubReleaseAsset shows a -LiteralPath that is no file without its credential'
    }
    @{
        Block    = { Save-GitHubReleaseAsset -Tag 'v1' -Destination 'Env:/user:SENTINEL@h.example/x' }
        Expected = "'***@h.example/x' is not a file system path (it is on the Environment provider)," +
        ' so gh cannot use it.'
        Name     = 'Save-GitHubReleaseAsset shows a -Destination off the file system without its credential'
    }
    @{
        Block    = { Save-GitHubReleaseAsset -Tag 'v1' -Output 'Env:/user:SENTINEL@h.example/x' }
        Expected = "'***@h.example/x' is not a file system path (it is on the Environment provider)," +
        ' so gh cannot use it.'
        Name     = 'and an -Output off the file system'
    }
)

# Act / Assert
foreach ($case in $messages) {
    Assert-Throws -ScriptBlock $case.Block -MessageLike (& $escape $case.Expected) -Message $case.Name
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing the URL on stdout and stderr
$fake = New-FakeGitHubCli -Output @("moved $url") -ErrorOutput @("Get `"$url`": HTTP 404") -ExitCode 1
$printed = "`nmoved $shown`nGet `"$shown`": HTTP 404"
$failures = @(
    @{
        Block    = { New-GitHubRelease -Tag $url -Title $url -Repository $url }
        Expected = "Creating release $shown failed: gh release create --title=$shown --repo $shown -- $shown" +
        " (exit 1)$printed"
        Name     = 'New-GitHubRelease shows no credential in the tag, the title, the repository, or gh''s output'
    }
    @{
        Block    = { Set-GitHubRelease -Tag $url -Title $url -Repository $url }
        Expected = "Editing release $shown failed: gh release edit --title=$shown --repo $shown -- $shown" +
        " (exit 1)$printed"
        Name     = 'Set-GitHubRelease shows no credential in the tag, the title, the repository, or gh''s output'
    }
    @{
        Block    = { Remove-GitHubRelease -Tag $url -Repository $url }
        Expected = "Deleting release $shown failed: gh release delete --yes --repo $shown -- $shown (exit 1)$printed"
        Name     = 'Remove-GitHubRelease shows no credential in the tag, the repository, or gh''s output'
    }
    @{
        Block    = { Add-GitHubReleaseAsset -Tag $url -Path "$url/a.zip" -Repository $url }
        Expected = "Uploading assets to release $shown failed: gh release upload --repo $shown -- $shown" +
        " $shown/a.zip (exit 1)$printed"
        Name     = 'Add-GitHubReleaseAsset shows no credential in the tag, a path, the repository, or gh''s output'
    }
    @{
        Block    = { Remove-GitHubReleaseAsset -Tag $url -Name $url -Repository $url }
        Expected = "Deleting asset $shown from release $shown failed: gh release delete-asset --yes --repo $shown" +
        " -- $shown $shown (exit 1)$printed"
        Name     = 'Remove-GitHubReleaseAsset shows no credential in the tag, asset, repository, or gh''s output'
    }
    @{
        Block    = { Save-GitHubReleaseAsset -Tag $url -Pattern $url -Repository $url }
        Expected = "Downloading the assets of release $shown failed: gh release download --pattern=$shown" +
        " --repo $shown -- $shown (exit 1)$printed"
        Name     = 'Save-GitHubReleaseAsset shows no credential in the tag, a pattern, the repository, or gh''s output'
    }
    @{
        Block    = { Get-GitHubRelease -Tag $url -Repository $url -Property tagName }
        Expected = "Reading release $shown failed: gh release view --json tagName,url --repo $shown -- $shown" +
        " (exit 1)$printed"
        Name     = 'Get-GitHubRelease shows no credential in the tag, the repository, or gh''s output'
    }
    @{
        Block    = { Get-GitHubRelease -List -Repository $url -Property tagName }
        Expected = "Listing releases failed: gh release list --json tagName --repo $shown (exit 1)$printed"
        Name     = 'and Get-GitHubRelease -List shows none in the repository or gh''s output'
    }
)
try {
    # Act / Assert
    foreach ($case in $failures) {
        Assert-Throws -ScriptBlock $case.Block -MessageLike (& $escape $case.Expected) -Message $case.Name
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that answers with text that is not JSON
$fake = New-FakeGitHubCli -Output @("moved $url")
try {
    # Act / Assert
    $start = "gh's output is not valid JSON, starting 'moved $shown': 'm' is an invalid start"
    Assert-Throws -ScriptBlock { Get-GitHubRelease -Tag 'v1' -Repository 'o/r' } `
        -MessageLike ((& $escape $start) + '*') `
        -Message 'Get-GitHubRelease shows no credential in an answer it cannot read'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
