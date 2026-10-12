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
# Arrange - a draft with inline notes and a target commit
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/releases/tag/v1.0.0')
try {
    # Act
    $release = @{
        Tag        = 'v1.0.0'
        Title      = 'v1.0.0'
        Notes      = "## Changes`n- one"
        Draft      = $true
        Target     = 'abc123'
        Repository = 'o/r'
    }
    $url = New-GitHubRelease @release
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = $call.Arguments[6]

    # Assert
    $expected = @(
        'release', 'create', '--title=v1.0.0', '--draft', '--target=abc123', '--notes-file', $file, '--repo', 'o/r',
        '--', 'v1.0.0'
    )
    Assert-Equal `
        -Expected $expected `
        -Actual $call.Arguments `
        -Message 'The notes are read from a file, the rest become their gh flags, and the tag comes last, after a --'
    Assert-Equal `
        -Expected "## Changes`n- one" `
        -Actual $call.Files[$file] `
        -Message 'The file holds the notes exactly, with no newline added'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped'
    Assert-Equal `
        -Expected 'https://github.com/o/r/releases/tag/v1.0.0' `
        -Actual $url `
        -Message 'The new release''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option that goes with generated notes, with assets
$folder = New-ReleaseTestFolder -File 'notes.md', 'a[1].zip'
$elsewhere = New-ReleaseTestFolder
$fake = New-FakeGitHubCli -Output @('Uploading a.zip...', 'https://github.com/o/r/releases/tag/v2')
try {
    # Act
    $url = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        $release = @{
            Tag                = 'v2'
            Asset              = @('a.zip', 'b.zip#Label')
            LiteralAsset       = 'a[1].zip'
            NotesFile          = 'notes.md'
            GenerateNotes      = $true
            NotesStartTag      = 'v1'
            Prerelease         = $true
            Latest             = $false
            VerifyTag          = $true
            DiscussionCategory = 'General'
            FailOnNoCommits    = $true
        }
        New-GitHubRelease @release
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'release', 'create', '--notes-file', (Join-Path $folder 'notes.md'), '--generate-notes',
        '--notes-start-tag=v1', '--prerelease', '--latest=false', '--verify-tag', '--discussion-category=General',
        '--fail-on-no-commits', '--', 'v2', 'a.zip', 'b.zip#Label', "$(Join-Path $folder 'a[1].zip')#"
    )
    Assert-Equal `
        -Expected $expected `
        -Actual $call.Arguments `
        -Message ('Each option becomes its gh flag, -NotesFile and -LiteralAsset resolved against PowerShell''s' +
            ' location, and the assets follow the tag')
    Assert-Equal `
        -Expected 'https://github.com/o/r/releases/tag/v2' `
        -Actual $url `
        -Message 'The URL is picked out from among upload progress lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - notes from the tag, and explicitly latest
$fake = New-FakeGitHubCli -Output @('https://x')
try {
    # Act
    New-GitHubRelease -Tag 'v3' -NotesFromTag -Latest | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'create', '--notes-from-tag', '--latest=true', '--', 'v3') `
        -Actual $call.Arguments `
        -Message '-NotesFromTag is its gh flag and -Latest alone marks the release latest'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a tag and an asset that look like options, and a title of --
$fake = New-FakeGitHubCli -Output @('https://x')
try {
    # Act
    New-GitHubRelease -Tag '--web' -Title '--' -Asset '-odd.zip' -Repository 'o/r' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'create', '--title=--', '--repo', 'o/r', '--', '--web', '-odd.zip') `
        -Actual $call.Arguments `
        -Message 'The tag and the assets are operands whatever they start with, and a title of -- is --title''s value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - calls that are refused before gh
$refusals = @(
    @{
        Call    = { New-GitHubRelease -Tag '  ' }
        Like    = "*'  ' is not a release tag*"
        Message = 'A blank tag is refused'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -Asset 'a.zip', '' }
        Like    = "Cannot validate argument on parameter 'Asset'." +
        ' -Asset holds a blank path: give the path of each file, or leave it out.'
        Message = 'An empty asset path is refused, not sent as a file'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -LiteralAsset ' ' }
        Like    = '*-LiteralAsset holds a blank path: give the path of each file, or leave it out.'
        Message = 'as is a blank literal asset path'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -NotesFile ' ' }
        Like    = '*-NotesFile is blank: give the path of a file, or leave it out.'
        Message = 'A blank notes file is refused'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -NotesStartTag ' ' }
        Like    = '*-NotesStartTag is blank: give a tag, or leave it out.'
        Message = 'A blank tag to start generated notes from is refused'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -Target ' ' }
        Like    = '*-Target is blank: give a branch name or a commit SHA, or leave it out.'
        Message = 'A blank target is refused'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -Title '' }
        Like    = '-Title is blank: give the release a title, or leave it out.'
        Message = 'An empty title is refused, not dropped without a word'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -Title ' ' }
        Like    = '-Title is blank: give the release a title, or leave it out.'
        Message = 'as is a blank one, not sent as a title of spaces'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -DiscussionCategory '' }
        Like    = '-DiscussionCategory is blank: give a discussion category, or leave it out.'
        Message = 'An empty discussion category is refused'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -DiscussionCategory ' ' }
        Like    = '-DiscussionCategory is blank: give a discussion category, or leave it out.'
        Message = 'as is a blank one'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -NotesFile '-' }
        Like    = "-NotesFile '-' would make gh read standard input: give the path of a file."
        Message = 'A notes file of - is refused, as gh would read standard input'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -NotesFile 'no-such-notes.md' }
        Like    = "-NotesFile 'no-such-notes.md' is not a file."
        Message = 'A notes file that is not there is refused'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -LiteralAsset 'no-such.zip' }
        Like    = "-LiteralAsset 'no-such.zip' is not a file."
        Message = 'A literal asset that is not there is refused, naming its parameter'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -Notes 'text' -NotesFile 'notes.md' }
        Like    = '-Notes and -NotesFile cannot be used together: gh would use the file*. Give only one.'
        Message = '-Notes with -NotesFile is refused, as gh would drop the text without saying so'
    }
    @{
        Call    = { New-GitHubRelease -Tag 'v1' -Repository $null }
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

    # Act
    $thrown = try {
        New-GitHubRelease -Tag 'v1' -DiscussionCategory ' '
    }
    catch {
        $_.Exception.Message
    }

    # Assert
    $expected = '-DiscussionCategory is blank: give a discussion category, or leave it out.'
    Assert-Equal -Expected $expected -Actual $thrown -Message 'The blank-value sentence is exactly the family''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refuses the release
$refusal = 'using `--notes-from-tag` with `--generate-notes` or `--notes-start-tag` is not supported'
$fake = New-FakeGitHubCli -ErrorOutput @($refusal) -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubRelease -Tag 'v1' -NotesFromTag -GenerateNotes
    } -MessageLike '*Creating release v1 failed*is not supported*' `
        -Message 'A refused combination throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with notes, a draft, and an asset
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/releases/tag/v1.2.0')
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        New-GitHubRelease -Tag 'v1.2.0' -Title 'One two' -Notes 'Private text' -Draft -Asset './dist/*.nupkg' `
            -Latest `
            -Repository 'o/r' `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Create release as a draft, uploading ./dist/*.nupkg"' +
    ' on target "o/r release v1.2.0".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the release and its assets, never the notes'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned, not even a URL'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$folder = New-ReleaseTestFolder -File 'a.zip'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -WhatIf with a literal asset, in the current directory's repository
    $fake = New-FakeGitHubCli
    try {
        # Act
        $asset = Join-Path $folder 'a.zip'
        $result = Get-WhatIfOutput -ScriptBlock {
            New-GitHubRelease -Tag 'v2' -LiteralAsset $asset -WhatIf
        }

        # Assert
        $expected = "What if: Performing the operation `"Create release, uploading $asset`" on target `"release v2`"."
        Assert-Equal -Expected @($expected) -Actual $result.Messages -Message 'A literal asset is named as given'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -WhatIf with a literal asset that is a folder
    $fake = New-FakeGitHubCli
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            New-GitHubRelease -Tag 'v2' -LiteralAsset $folder -WhatIf
        } -MessageLike "-LiteralAsset '*' is not a file." `
            -Message 'A folder is still refused under -WhatIf'
        Assert-Throws -ScriptBlock {
            New-GitHubRelease -Tag 'v2' -Notes 'x' -NotesFile 'notes.md' -WhatIf
        } -MessageLike '-Notes and -NotesFile cannot be used together: *. Give only one.' `
            -Message 'and so are -Notes with -NotesFile'
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
