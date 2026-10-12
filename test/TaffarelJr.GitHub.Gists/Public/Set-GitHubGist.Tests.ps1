#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubGistsTestHelper.ps1')

$elsewhere = [System.IO.Path]::GetTempPath()

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a new description
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description 'new desc'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'api', 'gists/bcd1234567890abcdef0', '--method', 'PATCH', '--raw-field', 'description=new desc', '--silent'
        ) `
        -Actual $call.Arguments `
        -Message 'The description is patched through the API, which sets it without opening an editor'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a description that looks like something gh would interpret
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description '@notes.md'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected 'description=@notes.md' -Actual $call.Arguments[5] `
        -Message 'The description is sent as text, never read from a file'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty description, which gh gist edit would ignore
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description ''
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'api', 'gists/bcd1234567890abcdef0', '--method', 'PATCH', '--raw-field', 'description=', '--silent'
        ) `
        -Actual $call.Arguments `
        -Message 'An empty description is sent, which clears it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a description that is $null, as an empty lookup gives it
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description $null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected 'description=' -Actual $call.Arguments[5] `
        -Message 'A $null description clears it, as an empty one does'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the gist given as a URL
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'https://gist.github.com/me/bcd1234567890abcdef0#file-a-txt' -Description 'x'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected 'gists/bcd1234567890abcdef0' -Actual $call.Arguments[1] `
        -Message 'A gist URL is reduced to its bare id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gist ids from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('a', 'b') | Set-GitHubGist -Description 'x'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped gist is changed in its own call'
    Assert-Equal -Expected 'gists/b' -Actual $calls[1].Arguments[1] -Message 'The second piped gist is changed too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gists from a listing, piped in
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = '[[{"id":"a1","html_url":"https://gist.github.com/me/a1"},{"id":"b2","html_url":"https://gist.github.com/me/b2"}]]' }
    @{ Output = @() }
)
try {
    # Act
    $gists = @(Get-GitHubGist -List)
    $gists | Set-GitHubGist -Description 'x'
    [PSCustomObject]@{ HtmlUrl = 'https://gist.github.com/me/c3c3c3c3c3c3c3c3c3c3' } | Set-GitHubGist -Description 'x'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('gists/a1', 'gists/b2', 'gists/c3c3c3c3c3c3c3c3c3c3') `
        -Actual @($calls[1..3] | ForEach-Object { $_.Arguments[1] }) `
        -Message 'A listed gist, or an object with only an HtmlUrl, is changed by what it names'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - adding a local file the gist does not have yet, relative to
# PowerShell's location
$folder = New-GistTestFolder -File @{ 'docs/new.txt' = 'n' }
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = '{"id":"bcd1234567890abcdef0","files":{"other.txt":{"filename":"other.txt"},"NEW.txt":{"filename":"NEW.txt"}}}' }
    @{ Output = @() }
)
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile 'docs/new.txt'
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'gists/bcd1234567890abcdef0') -Actual $calls[0].Arguments `
        -Message 'The gist is read first, for the names it already has'
    Assert-Equal -Expected @('gist', 'edit', '--add', (Join-Path $folder 'docs' 'new.txt'), 'bcd1234567890abcdef0') `
        -Actual $calls[1].Arguments `
        -Message 'then the file is added with --add, by its full path, and nothing else is given for gh to misread'
    Assert-Equal -Expected $false -Actual $calls[1].StdInPiped -Message 'and nothing is piped to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - adding a file under a name the gist already has
$folder = New-GistTestFolder -File @{ 'docs/new.txt' = 'n'; 'Values' = 'v' }
$fake = New-FakeGitHubCli `
    -Output @('{"id":"bcd1234567890abcdef0","files":{"new.txt":{"filename":"new.txt"},"Keys":{},"Values":{}}}')
try {
    # Act / Assert
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile 'docs/new.txt'
        } -MessageLike "Gist bcd1234567890abcdef0 already has a file named 'new.txt', which -AddFile would silently replace; to replace it, give -FileName 'new.txt' -ReplaceWith 'docs/new.txt'." `
            -Message 'A file the gist already has is refused, not silently replaced'
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile 'Values'
        } -MessageLike "Gist bcd1234567890abcdef0 already has a file named 'Values'*" `
            -Message 'even one named like a member of the file list'
    }
    Assert-Equal -Expected 2 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'after reading the gist, and before gh edits it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - adding a file to a gist whose file list GitHub cut short
$folder = New-GistTestFolder -File @{ 'y.txt' = 'y' }
$fake = New-FakeGitHubCli -Output @('{"id":"bcd1234567890abcdef0","truncated":true,"files":{"x.txt":{}}}')
try {
    # Act / Assert
    $warnings = @(Get-WarningOutput -ScriptBlock {
            Assert-Throws -ScriptBlock {
                Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile (Join-Path $folder 'y.txt')
            } -MessageLike "Gist bcd1234567890abcdef0 has more than 300 files, and GitHub lists only the first 300, so whether it already has a file named 'y.txt' cannot be told: clone it with Copy-GitHubGist and add the file there." `
                -Message 'A gist with more files than GitHub lists is refused, as the name cannot be checked'
        })
    Assert-Equal -Expected 0 -Actual $warnings.Count -Message 'without the listing''s warning about cloning'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and before gh edits it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gist that cannot be read before adding to it
$folder = New-GistTestFolder -File @{ 'new.txt' = 'n' }
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Not Found (HTTP 404)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile (Join-Path $folder 'new.txt')
    } -MessageLike 'Reading gist bcd1234567890abcdef0 failed*Not Found (HTTP 404)' `
        -Message 'A gist that cannot be read throws, and nothing is added'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - removing a file
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile 'old.txt'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'edit', '--remove=old.txt', 'bcd1234567890abcdef0') -Actual $call.Arguments `
        -Message 'A file is removed with --remove, its name joined to the flag'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - replacing a file's content from a local file, relative to
# PowerShell's location
$folder = New-GistTestFolder -File @{ 'local.py' = 'print(1)' }
$fake = New-FakeGitHubCli
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName '--hello.py' -ReplaceWith 'local.py'
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('gist', 'edit', '--filename=--hello.py', 'bcd1234567890abcdef0', (Join-Path $folder 'local.py')) `
        -Actual $call.Arguments `
        -Message '-FileName is joined to its flag, and -ReplaceWith follows the id as a full path'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - local files that are missing, or that a gist cannot hold
$files = @{
    'empty.txt'  = ''
    'blank.txt'  = " `n"
    'bin.dat'    = [byte[]](0x41, 0x00, 0x42)
    'latin1.txt' = [byte[]](0x63, 0xE9)
}
$folder = New-GistTestFolder -File $files
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile 'nope.txt'
        } -MessageLike "-AddFile 'nope.txt' is not a file." -Message 'A file to add that does not exist is refused'
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName 'a.py' -ReplaceWith 'nope.py'
        } -MessageLike "-ReplaceWith 'nope.py' is not a file." -Message 'and so is a missing replacement'
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName 'a.py' -ReplaceWith '-'
        } -MessageLike "-ReplaceWith '-' would make gh read standard input: give the path of a file." `
            -Message 'and a lone dash, which gh would read as standard input'
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile 'empty.txt'
        } -MessageLike "-AddFile 'empty.txt' is empty or only whitespace, and GitHub refuses a gist file with no content." `
            -Message 'An empty file is refused, as New-GitHubGist refuses it'
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName 'a.txt' -ReplaceWith 'blank.txt'
        } -MessageLike "-ReplaceWith 'blank.txt' is empty or only whitespace, and GitHub refuses a gist file with no content." `
            -Message 'and so is a blank one'
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile 'bin.dat'
        } -MessageLike "-AddFile 'bin.dat' holds binary data, and a gist holds text only." -Message 'and a binary one'
        Assert-Throws -ScriptBlock {
            Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName 'a.txt' -ReplaceWith 'latin1.txt'
        } -MessageLike "-ReplaceWith 'latin1.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first." `
            -Message 'and one that is not UTF-8'
    }
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two changes at once, which gh gist edit would mix up, half of
# a replacement, nothing to change, and blank values
$cases = @(
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile 'a.txt' -RemoveFile 'b.txt' }
        Like = '-AddFile and -RemoveFile cannot be used together: gh gist edit mixes changes up, so one is made per call. Give only one.'
        Message = 'A file added and another removed in one call is refused'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description 'x' -FileName 'a.txt' -ReplaceWith 'b.txt' }
        Like = '-Description and -FileName cannot be used together: gh gist edit mixes changes up, so one is made per call. Give only one.'
        Message = 'as is a description with a replacement'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName 'a.txt' }
        Like = '-FileName works only with -ReplaceWith: it names the gist file whose content -ReplaceWith replaces. Give -ReplaceWith too, or leave -FileName off.'
        Message = 'A file to replace with no replacement is refused'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -ReplaceWith 'b.txt' }
        Like = '-ReplaceWith works only with -FileName: it replaces the content of the gist file -FileName names. Give -FileName too, or leave -ReplaceWith off.'
        Message = 'and a replacement with no file to replace'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' }
        Like = 'Say what to change - -Description, -AddFile, -RemoveFile, or -FileName with -ReplaceWith.'
        Message = 'Nothing to change is refused, saying what can change'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile ' ' }
        Like = '*-RemoveFile is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'A blank file to remove is refused'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile 'a/b' }
        Like = '*-RemoveFile is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'and so is one with a slash, which no gist file name holds'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile "a`nb" }
        Like = '*-RemoveFile is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a line break'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile "a`rb" }
        Like = '*-RemoveFile is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a carriage return'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile "a`0b" }
        Like = '*-RemoveFile is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a NUL'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile "a`u{2028}b" }
        Like = '*-RemoveFile is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a Unicode line separator'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile '' }
        Like = '*-AddFile is blank: give the path of a local file, or leave it out.'
        Message = 'and a blank file to add'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName '' -ReplaceWith 'b.txt' }
        Like = '*-FileName is blank: give the name of a file in the gist, or leave it out.'
        Message = 'and a blank file to replace'
    }
    @{
        Call = { Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName 'a.txt' -ReplaceWith ' ' }
        Like = '*-ReplaceWith is blank: give the path of a local file, or leave it out.'
        Message = 'and a blank replacement'
    }
    @{
        Call = { Set-GitHubGist -Id '-abc' -Description 'x' }
        Like = "'-abc' is not a gist: give its id or URL, or a gist object."
        Message = 'An id that is not one is refused'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($case in $cases) {
        Assert-Throws -ScriptBlock $case.Call -MessageLike $case.Like -Message $case.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - GitHub does not know the gist
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Not Found (HTTP 404)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description 'x'
    } -MessageLike 'Setting the description of gist bcd1234567890abcdef0 failed: gh api gists/bcd1234567890abcdef0*Not Found (HTTP 404)' `
        -Message 'A description change that fails throws with the API''s message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh will not remove a file the gist does not have
$fake = New-FakeGitHubCli -ErrorOutput @('gist has no file "old.txt"') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile 'old.txt'
    } -MessageLike 'Editing gist bcd1234567890abcdef0 failed*gist has no file "old.txt"' `
        -Message 'A file change that fails throws with gh''s message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with each change but adding a file
$folder = New-GistTestFolder -File @{ 'new.txt' = 'Secret text' }
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description 'Secret description' -WhatIf
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -RemoveFile 'old.txt' -WhatIf
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -FileName 'a.txt' -ReplaceWith (Join-Path $folder 'new.txt') -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Edit description" on target "gist bcd1234567890abcdef0".'
        'What if: Performing the operation "Remove file old.txt" on target "gist bcd1234567890abcdef0".'
        'What if: Performing the operation "Replace file a.txt" on target "gist bcd1234567890abcdef0".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the gist and the change, never the description or a file''s content'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and changes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a file to add
$folder = New-GistTestFolder -File @{ 'new.txt' = 'Secret text' }
$fake = New-FakeGitHubCli -Output @('{"id":"bcd1234567890abcdef0","files":{"x.txt":{"filename":"x.txt"}}}')
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile (Join-Path $folder 'new.txt') -WhatIf
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    $expected = @('What if: Performing the operation "Add file new.txt" on target "gist bcd1234567890abcdef0".')
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names the gist and the file it would add'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'after only reading the gist'
    Assert-Equal -Expected @('api', 'gists/bcd1234567890abcdef0') -Actual $calls[0].Arguments `
        -Message 'for the names it already has'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a file the gist already has, and with two changes
$folder = New-GistTestFolder -File @{ 'new.txt' = 'n' }
$fake = New-FakeGitHubCli -Output @('{"id":"bcd1234567890abcdef0","files":{"new.txt":{"filename":"new.txt"}}}')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -AddFile (Join-Path $folder 'new.txt') -WhatIf
    } -MessageLike "Gist bcd1234567890abcdef0 already has a file named 'new.txt'*" `
        -Message '-WhatIf still refuses a file the gist already has'
    Assert-Throws -ScriptBlock {
        Set-GitHubGist -Id 'bcd1234567890abcdef0' -Description 'd' -RemoveFile 'b.txt' -WhatIf
    } -MessageLike '-Description and -RemoveFile cannot be used together*' -Message 'and two changes in one call'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'after only reading the gist'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two gists piped under -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @('a1', 'b2') | Set-GitHubGist -RemoveFile 'old.txt' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Remove file old.txt" on target "gist a1".'
        'What if: Performing the operation "Remove file old.txt" on target "gist b2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped gist'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and changes neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
