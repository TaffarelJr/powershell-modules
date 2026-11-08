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

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Rename-GitHubGistFile -Id 'bcd1234567890abcdef0' -OldName 'old.txt' -NewName 'new.txt'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'rename', '--', 'bcd1234567890abcdef0', 'old.txt', 'new.txt') `
        -Actual $call.Arguments `
        -Message 'The id and both names are positional, in order, after a -- that ends the options'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - file names that start with a dash
$fake = New-FakeGitHubCli
try {
    # Act
    Rename-GitHubGistFile -Id 'bcd1234567890abcdef0' -OldName '-old.txt' -NewName '--new.txt'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'rename', '--', 'bcd1234567890abcdef0', '-old.txt', '--new.txt') `
        -Actual $call.Arguments `
        -Message 'A name starting with a dash is passed as a name, after the --'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the gist id piped in by property
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Id = 'xyz' } | Rename-GitHubGistFile -OldName 'a' -NewName 'b'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'rename', '--', 'xyz', 'a', 'b') -Actual $call.Arguments `
        -Message 'The Id property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the URL New-GitHubGist returns, piped in, and an object with only
# an HtmlUrl
$fake = New-FakeGitHubCli
try {
    # Act
    'https://gist.github.com/me/bcd1234567890abcdef0' | Rename-GitHubGistFile -OldName 'a' -NewName 'b'
    [PSCustomObject]@{ HtmlUrl = 'https://gist.github.com/me/fedcba9876543210fedc' } | Rename-GitHubGistFile `
        -OldName 'a' `
        -NewName 'b'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('gist', 'rename', '--', 'bcd1234567890abcdef0', 'a', 'b') -Actual $calls[0].Arguments `
        -Message 'A gist piped in as text is renamed in'
    Assert-Equal -Expected @('gist', 'rename', '--', 'fedcba9876543210fedc', 'a', 'b') -Actual $calls[1].Arguments `
        -Message 'and an object is read by its HtmlUrl, not turned into its text'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the gist given as a URL
$fake = New-FakeGitHubCli
try {
    # Act
    Rename-GitHubGistFile -Id 'https://gist.github.com/me/bcd1234567890abcdef0' -OldName 'a' -NewName 'b'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected 'bcd1234567890abcdef0' -Actual $call.Arguments[3] `
        -Message 'A gist URL is reduced to its bare id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that is not a gist
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Rename-GitHubGistFile -Id '-abc' -OldName 'a' -NewName 'b'
    } -MessageLike "*'-abc' is not a gist: give its id or URL, or a gist object." `
        -Message 'An id that is not one is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - file names that are empty or blank
$cases = @(
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName '' -NewName 'b' }
        Like = '*-OldName is blank: give the name of a file in the gist.'
        Message = 'An empty old name is refused'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName ' ' -NewName 'b' }
        Like = '*-OldName is blank: give the name of a file in the gist.'
        Message = 'and so is a blank one'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName '' }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'An empty new name is refused'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName "`t" }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'and so is a blank one'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName 'b/c' }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'and a new name with a slash, which GitHub refuses'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName 'b\c' }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a backslash'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName "b`nc" }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a line break'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName "b`rc" }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a carriage return, which the message does not print'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName "b`0c" }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a NUL, which would cut the name short on its way to gh'
    }
    @{
        Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName "b`u{2028}c" }
        Like = '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        Message = 'or a Unicode line separator'
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
# Arrange - the gist has no such file
$fake = New-FakeGitHubCli -ErrorOutput @('File old.txt not found in gist') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Rename-GitHubGistFile -Id 'bcd1234567890abcdef0' -OldName 'old.txt' -NewName 'new.txt'
    } -MessageLike '*Renaming old.txt in gist bcd1234567890abcdef0 failed*File old.txt not found in gist*' `
        -Message 'A failed rename throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with both names
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Rename-GitHubGistFile -Id 'bcd1234567890abcdef0' -OldName 'old.txt' -NewName 'new.txt' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Rename file old.txt to new.txt"' +
        ' on target "gist bcd1234567890abcdef0".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names the gist and both names'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and renames nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a new name GitHub would refuse, and a value that is
# not a gist
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Rename-GitHubGistFile -Id 'bcd1234567890abcdef0' -OldName 'old.txt' -NewName 'a/b.txt' -WhatIf
    } -MessageLike '*-NewName is not a gist file name: it is blank or holds /, \, or a control character.' `
        -Message '-WhatIf still refuses a new name GitHub would refuse'
    Assert-Throws -ScriptBlock {
        Rename-GitHubGistFile -Id '-abc' -OldName 'old.txt' -NewName 'new.txt' -WhatIf
    } -MessageLike "*'-abc' is not a gist: give its id or URL, or a gist object." `
        -Message 'and a value that is not a gist'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two gists piped under -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @('a1', 'b2') | Rename-GitHubGistFile -OldName 'old.txt' -NewName 'new.txt' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Rename file old.txt to new.txt" on target "gist a1".'
        'What if: Performing the operation "Rename file old.txt to new.txt" on target "gist b2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped gist'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and renames in neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
