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
# Arrange - publishing a draft
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/releases/tag/v1.0.0')
try {
    # Act
    $url = Set-GitHubRelease -Tag 'v1.0.0' -Draft:$false -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'edit', '--draft=false', '--repo', 'o/r', '--', 'v1.0.0') `
        -Actual $call.Arguments `
        -Message '-Draft:$false publishes the draft, and the tag comes last, after a --'
    Assert-Equal `
        -Expected 'https://github.com/o/r/releases/tag/v1.0.0' `
        -Actual $url `
        -Message 'The release''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option, with notes as text
$fake = New-FakeGitHubCli
try {
    # Act
    $edit = @{
        Tag                = 'v1'
        Title              = 'One'
        Notes              = "Body`n"
        NewTag             = 'v1.0.0'
        Target             = 'main'
        Draft              = $true
        Prerelease         = $true
        Latest             = $false
        VerifyTag          = $true
        DiscussionCategory = 'General'
    }
    Set-GitHubRelease @edit
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = $call.Arguments[-3]

    # Assert
    $expected = @(
        'release', 'edit', '--title=One', '--tag=v1.0.0', '--target=main', '--draft=true', '--prerelease=true',
        '--latest=false', '--verify-tag', '--discussion-category=General', '--notes-file', $file, '--', 'v1'
    )
    Assert-Equal `
        -Expected $expected `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, the toggles as explicit booleans'
    Assert-Equal -Expected "Body`n" -Actual $call.Files[$file] -Message 'The notes file holds the notes exactly'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - clearing the title and the notes
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRelease -Tag 'v1' -Title '' -Notes ''
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'edit', '--title=', '--notes-file') `
        -Actual @($call.Arguments[0..3]) `
        -Message 'An empty title is sent empty, which clears it'
    Assert-Equal `
        -Expected '' `
        -Actual $call.Files[$call.Arguments[4]] `
        -Message 'and empty notes are an empty file, which clears them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - notes as the only change
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRelease -Tag 'v1' -Notes 'text'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)
    $file = $calls[0].Arguments[3]

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message '-Notes alone is something to change: one edit call'
    Assert-Equal `
        -Expected @('release', 'edit', '--notes-file', $file, '--', 'v1') `
        -Actual $calls[0].Arguments `
        -Message 'and the notes reach gh through a file'
    Assert-Equal -Expected 'text' -Actual $calls[0].Files[$file] -Message 'that holds them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - notes from a relative file, and a tag that looks like an option
$folder = New-ReleaseTestFolder -File 'n.md'
$elsewhere = New-ReleaseTestFolder
$fake = New-FakeGitHubCli
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Set-GitHubRelease -Tag '--web' -NotesFile 'n.md' | Out-Null
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'edit', '--notes-file', (Join-Path $folder 'n.md'), '--', '--web') `
        -Actual $call.Arguments `
        -Message '-NotesFile is resolved against PowerShell''s location, and a tag is an operand whatever it holds'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - drafts piped in from a listing of another repository, with notes
$fake = New-FakeGitHubCli
try {
    # Act
    $drafts = @(
        [PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }
        [PSCustomObject]@{ TagName = 'v2'; Repository = 'a/b' }
    )
    $drafts | Set-GitHubRelease -Draft:$false -Notes 'Out now'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)
    $file = $calls[1].Arguments[4]

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped release is edited in its own call'
    Assert-Equal `
        -Expected @('release', 'edit', '--draft=false', '--notes-file', $file, '--repo', 'a/b', '--', 'v2') `
        -Actual $calls[1].Arguments `
        -Message 'in the repository it came from'
    Assert-Equal -Expected 'Out now' -Actual $calls[1].Files[$file] -Message 'with the notes given'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release from another repository given as -Tag, not piped
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRelease -Tag ([PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }) -Title 'One'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'edit', '--title=One', '--repo', 'a/b', '--', 'v1') `
        -Actual $call.Arguments `
        -Message 'A release given by name is edited in the repository it came from too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - calls that are refused before gh
$refusals = @(
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -Repository 'o/r' }
        Like    = 'Say what to change - for example -Title, -Notes, -NewTag, or -Draft.'
        Message = 'A call that changes nothing is refused, -Repository or not'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -VerifyTag }
        Like    = '-VerifyTag works only with -NewTag: it checks that the tag -NewTag names exists.' +
        ' Give -NewTag too, or leave -VerifyTag off.'
        Message = '-VerifyTag without -NewTag is refused, as it would check nothing'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -NewTag ' ' }
        Like    = '*-NewTag is blank: give the new tag''s name, or leave it out.'
        Message = 'A blank new tag is refused, as gh would ignore it'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -Target ' ' }
        Like    = '*-Target is blank: give a branch name or a commit SHA, or leave it out.'
        Message = 'A blank target is refused'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -NotesFile ' ' }
        Like    = '*-NotesFile is blank: give the path of a file, or leave it out.'
        Message = 'A blank notes file is refused'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -DiscussionCategory '' }
        Like    = '-DiscussionCategory is blank: give a discussion category, or leave it out.'
        Message = 'An empty discussion category is refused, as it would mean nothing to gh'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -DiscussionCategory ' ' }
        Like    = '-DiscussionCategory is blank: give a discussion category, or leave it out.'
        Message = 'as is a blank one'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -NotesFile '-' }
        Like    = "-NotesFile '-' would make gh read standard input: give the path of a file."
        Message = 'A notes file of - is refused'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -Notes 'text' -NotesFile 'n.md' }
        Like    = '-Notes and -NotesFile cannot be used together: gh would use the file*. Give only one.'
        Message = '-Notes with -NotesFile is refused, as gh would drop the text without saying so'
    }
    @{
        Call    = { 'v1' | Set-GitHubRelease -Notes 'text' -NotesFile 'n.md' }
        Like    = '-Notes and -NotesFile cannot be used together*'
        Message = 'with a tag piped in too'
    }
    @{
        Call    = { Set-GitHubRelease -Tag 'v1' -Title 'x' -Repository $null }
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
        Set-GitHubRelease -Tag 'v1' -Repository 'o/r'
    }
    catch {
        $_.Exception.Message
    }

    # Assert
    $expected = 'Say what to change - for example -Title, -Notes, -NewTag, or -Draft.'
    Assert-Equal -Expected $expected -Actual $thrown -Message 'The message is a sentence, starting with a capital'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refuses the edit
$fake = New-FakeGitHubCli -ErrorOutput @('release not found') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRelease -Tag 'v9' -Title 'x'
    } -MessageLike '*Editing release v9 failed*release not found*' -Message 'A failure throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with notes and every toggle
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/releases/tag/v1')
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubRelease -Tag 'v1' -Title 'One' -Notes 'Private text' -Draft:$false -Prerelease -Latest `
            -Repository 'o/r' `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Edit release" on target "o/r release v1".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the release and the change, never the notes'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned, not even a URL'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two releases piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        $releases = @('v1', [PSCustomObject]@{ TagName = 'v2'; Repository = 'other/repo' })
        $releases | Set-GitHubRelease -Draft:$false -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Edit release" on target "release v1".'
        'What if: Performing the operation "Edit release" on target "other/repo release v2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped release is named on its own, in the repository it came from'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and none is edited'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf and nothing to change
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubRelease -Tag 'v1' -WhatIf
    } -MessageLike 'Say what to change - for example -Title, -Notes, -NewTag, or -Draft.' `
        -Message '-WhatIf is not taken for a change to make'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
