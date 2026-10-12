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

$created = '{"id":"abc123","html_url":"https://gist.github.com/me/abc123"}'
$elsewhere = [System.IO.Path]::GetTempPath()

#───────────────────────────────────────────────────────────────────────────────
# Arrange - local files, relative to PowerShell's location, with line feeds,
# Windows line endings and characters beyond ASCII
$folder = New-GistTestFolder -File @{ 'a.txt' = "A`n"; 'b.txt' = "B`r`nliné ✓" }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    $url = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        New-GitHubGist -Path @('a.txt', 'b.txt') -Description 'notes' -Public
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists', '--method', 'POST', '--input', '-') -Actual $call.Arguments `
        -Message 'The gist is created through the API, with the request on standard input'
    Assert-Equal `
        -Expected '{"description":"notes","files":{"a.txt":{"content":"A\n"},"b.txt":{"content":"B\r\nliné ✓"}},"public":true}' `
        -Actual $call.StdIn `
        -Message 'holding each file under its own name with its exact content, read from PowerShell''s location'
    Assert-Equal -Expected 'https://gist.github.com/me/abc123' -Actual $url -Message "The new gist's URL is returned"
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a script that Windows PowerShell saved as UTF-8 with a byte-order mark
$script = [byte[]](0xEF, 0xBB, 0xBF, 0x23, 0x21, 0x2F, 0x62, 0x69, 0x6E, 0x2F, 0x73, 0x68, 0x0A)
$folder = New-GistTestFolder -File @{ 'run.sh' = $script }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    New-GitHubGist -Path (Join-Path $folder 'run.sh') | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = '{"description":"","files":{"run.sh":{"content":"#!/bin/sh\n"}},"public":false}'
    Assert-That `
        -Condition ([string]::Equals($expected, $call.StdIn, [StringComparison]::Ordinal)) `
        -Message 'The mark is not sent, so the script starts with #! on GitHub'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no description and no -Public
$folder = New-GistTestFolder -File @{ 'a.txt' = 'A' }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    New-GitHubGist -Path (Join-Path $folder 'a.txt') | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected '{"description":"","files":{"a.txt":{"content":"A"}},"public":false}' -Actual $call.StdIn `
        -Message 'The gist is secret, with an empty description, as gh gist create makes it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -Public with no description
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    New-GitHubGist -Content 'A' -FileName 'a.txt' -Public | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected '{"description":"","files":{"a.txt":{"content":"A"}},"public":true}' -Actual $call.StdIn `
        -Message 'A public gist is sent as public true, with an empty description'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - wildcards in two folders whose files have different names, beside
# a hidden file
$folder = New-GistTestFolder -File @{ 'one/x.md' = 'x'; 'two/y.md' = 'y'; 'two/skip.txt' = 's'; 'two/.h.md' = 'h' }
# Hidden by its leading dot off Windows, and by this attribute on it.
$hidden = Get-Item -LiteralPath (Join-Path $folder 'two/.h.md') -Force
$hidden.Attributes = $hidden.Attributes -bor [System.IO.FileAttributes]::Hidden
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        New-GitHubGist -Path @('one/*.md', 'two/*.md') | Out-Null
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected '{"description":"","files":{"x.md":{"content":"x"},"y.md":{"content":"y"}},"public":false}' `
        -Actual $call.StdIn `
        -Message 'Wildcards are expanded here, to the files they match, hidden ones aside'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file named outright, and a wildcard matching another of that name
$folder = New-GistTestFolder -File @{ 'one/notes.md' = '1'; 'two/notes.md' = '2' }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            New-GitHubGist -Path @('one/notes.md', 'two/*')
        }
    } -MessageLike "More than one of the -Path files is named 'notes.md', and a gist holds one file per name." `
        -Message 'Names are compared after the wildcards are expanded'
    Assert-Throws -ScriptBlock {
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            New-GitHubGist -Path @('one/notes.md', 'two/notes.md')
        }
    } -MessageLike "More than one of the -Path files is named 'notes.md', and a gist holds one file per name." `
        -Message 'and two files named outright with one name are refused too'
    Assert-Throws -ScriptBlock {
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            New-GitHubGist -Path @('one/notes.md', 'one/notes.md')
        }
    } -MessageLike "-Path names the file '$(Join-Path $folder 'one' 'notes.md')' more than once: give each file once." `
        -Message 'One file named twice is refused as that'
    Assert-Throws -ScriptBlock {
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            New-GitHubGist -Path @('one/notes.md', 'one/n*')
        }
    } -MessageLike "-Path names the file '$(Join-Path $folder 'one' 'notes.md')' more than once: give each file once." `
        -Message 'and so is one named outright that a wildcard matches too'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two files whose names differ only in case
$folder = New-GistTestFolder -File @{ 'one/Notes.md' = '1'; 'two/notes.md' = '2' }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        New-GitHubGist -Path @('one/Notes.md', 'two/notes.md') | Out-Null
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected '{"description":"","files":{"Notes.md":{"content":"1"},"notes.md":{"content":"2"}},"public":false}' `
        -Actual $call.StdIn `
        -Message 'Names are compared as written, so a different case is a different file'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name starting with a dash, and one with brackets, escaped
$folder = New-GistTestFolder -File @{ '-notes.md' = 'n'; 'a[1].txt' = 'b' }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        New-GitHubGist -Path @('-notes.md', 'a`[1`].txt') | Out-Null
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected '{"description":"","files":{"-notes.md":{"content":"n"},"a[1].txt":{"content":"b"}},"public":false}' `
        -Actual $call.StdIn `
        -Message 'A leading dash is part of a name, and an escaped bracket is a bracket'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - paths that name no file to send
$files = @{
    'a[1].txt'   = 'x'
    'empty.txt'  = ''
    'blank.txt'  = " `r`n"
    'bin.dat'    = [byte[]](0x41, 0x00, 0x42)
    'latin1.txt' = [byte[]](0x63, 0x61, 0x66, 0xE9)
}
$folder = New-GistTestFolder -File $files -Folder @('sub')
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act / Assert
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'missing.txt'
        } -MessageLike "'missing.txt' is not a file." -Message 'A file that does not exist is refused'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path '-'
        } -MessageLike "'-' is not a file." `
            -Message 'as is a lone dash, which is a name like any other, never standard input'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'sub/'
        } -MessageLike "'sub/' is not a file." -Message 'as is a folder'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'bin.dat.'
        } -MessageLike "'bin.dat.' is not a file." `
            -Message 'as is a name with a trailing dot, which Windows would open as another file''s'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path '*.none'
        } -MessageLike "'``*.none' matches no file." -Message 'A wildcard that matches no file is refused'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'sub*'
        } -MessageLike "'sub``*' matches no file." -Message 'as is one that matches only a folder'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'a[1].txt'
        } -MessageLike '''a`[1`].txt'' matches no file.' `
            -Message 'Unescaped brackets are a wildcard, so a[1].txt does not name the file a[1].txt'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'empty.txt'
        } -MessageLike "'empty.txt' is empty or only whitespace, and GitHub refuses a gist file with no content." `
            -Message 'An empty file is refused, named as it was typed'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'blank.txt'
        } -MessageLike "'blank.txt' is empty or only whitespace, and GitHub refuses a gist file with no content." `
            -Message 'and so is a file of whitespace alone'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'bla*.txt'
        } -MessageLike "'$(Join-Path $folder 'blank.txt')' is empty or only whitespace, and GitHub refuses a gist file with no content." `
            -Message 'A file a wildcard matched is named by its full path'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'bin.dat'
        } -MessageLike "'bin.dat' holds binary data, and a gist holds text only." -Message 'A binary file is refused'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'latin1.txt'
        } -MessageLike "'latin1.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first." `
            -Message 'A file that is not UTF-8 is refused, not sent garbled'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'Env:\PATH'
        } -MessageLike "*'Env:\PATH' is not a file system path*" -Message 'A path on another provider is refused'
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'Env:\PAT*'
        } -MessageLike "*'Env:\PAT``*' is not a file system path*" -Message 'with a wildcard too'
    }
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - content given directly, named, described and public
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    $url = New-GitHubGist -Content "line 1`nline 2" -FileName 'notes.md' -Description 'd' -Public
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists', '--method', 'POST', '--input', '-') -Actual $call.Arguments `
        -Message 'Content is created through the API too'
    Assert-Equal -Expected '{"description":"d","files":{"notes.md":{"content":"line 1\nline 2"}},"public":true}' `
        -Actual $call.StdIn `
        -Message 'as one file named by -FileName, exactly as given, with no newline added'
    Assert-Equal -Expected 'https://gist.github.com/me/abc123' -Actual $url `
        -Message 'The URL is returned for a content-based gist too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - content read with Get-Content, which notes its source on the text
$folder = New-GistTestFolder -File @{ 'a.txt' = 'text' }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    $text = Get-Content -LiteralPath (Join-Path $folder 'a.txt') -Raw
    New-GitHubGist -Content $text -FileName 'a.txt' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected '{"description":"","files":{"a.txt":{"content":"text"}},"public":false}' `
        -Actual $call.StdIn `
        -Message 'Only the text is sent, not the notes PowerShell keeps on it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - binary content
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content "a`0b" -FileName 'x.bin'
    } -MessageLike '-Content holds binary data, and a gist holds text only.' `
        -Message 'Content with binary characters is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - content and file names GitHub would refuse with a bare 422
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content '   ' -FileName 'w.txt'
    } -MessageLike '-Content is empty or only whitespace, and GitHub refuses a gist file with no content.' `
        -Message 'Content of whitespace alone is refused'
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content '' -FileName 'w.txt'
    } -MessageLike '-Content is empty or only whitespace, and GitHub refuses a gist file with no content.' `
        -Message 'and so is empty content, in the same words'
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content 'x' -FileName 'a/b.txt'
    } -MessageLike '*-FileName is not a gist file name: it is blank or holds /, \, or a control character.' `
        -Message 'A file name with a slash is refused'
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content 'x' -FileName 'a\b.txt'
    } -MessageLike '*-FileName is not a gist file name: it is blank or holds /, \, or a control character.' `
        -Message 'and one with a backslash'
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content 'x' -FileName ' '
    } -MessageLike '*-FileName is not a gist file name: it is blank or holds /, \, or a control character.' `
        -Message 'and a blank one'
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content 'x' -FileName "a`nb.txt"
    } -MessageLike '*-FileName is not a gist file name: it is blank or holds /, \, or a control character.' `
        -Message 'and one with a line break'
    foreach ($name in "a`rb.txt", "a`0b.txt", "a`u{2028}b.txt") {
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Content 'x' -FileName $name
        } -MessageLike '*-FileName is not a gist file name: it is blank or holds /, \, or a control character.' `
            -Message 'and one with a carriage return, a NUL, or a Unicode line separator'
    }
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - sources given together, halves of one given alone, or none
$cases = @(
    @{
        Call = { New-GitHubGist -Path 'a.txt' -Content 'x' -FileName 'b.txt' }
        Like = '-Path and -Content cannot be used together: a gist is made from files or from content. Give only one.'
        Message = 'Files and content together are refused'
    }
    @{
        Call = { New-GitHubGist -Path 'a.txt' -FileName 'b.txt' }
        Like = '-Path and -FileName cannot be used together: each -Path file keeps its own name. Give only one.'
        Message = 'as is a file name for files'
    }
    @{
        Call = { New-GitHubGist -Content 'x' }
        Like = '-Content works only with -FileName: its file needs a name in the gist. Give -FileName too, or leave -Content off.'
        Message = 'Content without a name is refused'
    }
    @{
        Call = { New-GitHubGist -FileName 'b.txt' }
        Like = '-FileName works only with -Content: it names the file -Content becomes. Give -Content too, or leave -FileName off.'
        Message = 'and a name without content'
    }
    @{
        Call = { New-GitHubGist -Description 'd' }
        Like = 'Say what the gist is to hold - -Path, or -Content with -FileName.'
        Message = 'and no source at all'
    }
)
$fake = New-FakeGitHubCli -Output @($created)
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
# Arrange - GitHub answers without the gist's URL
$fake = New-FakeGitHubCli -Output @('{"id":"abc123"}')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content 'text' -FileName 'notes.md'
    } -MessageLike '*Creating the gist succeeded, but GitHub''s answer has no html_url to return*' `
        -Message 'An answer with no URL throws instead of returning nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - GitHub refuses the gist
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Validation Failed (HTTP 422)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Content 'text' -FileName 'notes.txt'
    } -MessageLike '*Creating the gist failed: gh api gists*Validation Failed (HTTP 422)*' `
        -Message "A failure throws with GitHub's own message"
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with files, a description, and -Public
$folder = New-GistTestFolder -File @{ 'a.txt' = 'Secret text'; 'b.txt' = 'B' }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    $whatIf = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Get-WhatIfOutput -ScriptBlock {
            New-GitHubGist -Path @('a.txt', 'b.txt') -Description 'notes' -Public -WhatIf
        }
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Create public gist" on target "a.txt, b.txt".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the files the gist would hold, never their content'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns no URL'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and sends nothing to GitHub'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with content given directly
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        New-GitHubGist -Content 'Secret text' -FileName 'note.md' -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Create secret gist" on target "note.md".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the file and a secret gist, never the content'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and sends nothing to GitHub'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a file that cannot be sent, and with no source
$folder = New-GistTestFolder -File @{ 'empty.txt' = '' }
$fake = New-FakeGitHubCli -Output @($created)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Path (Join-Path $folder 'empty.txt') -WhatIf
    } -MessageLike '*is empty or only whitespace, and GitHub refuses a gist file with no content.' `
        -Message '-WhatIf still reads and refuses an empty file'
    Assert-Throws -ScriptBlock {
        New-GitHubGist -Description 'notes' -WhatIf
    } -MessageLike 'Say what the gist is to hold - -Path, or -Content with -FileName.' `
        -Message 'and a gist with no source'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
