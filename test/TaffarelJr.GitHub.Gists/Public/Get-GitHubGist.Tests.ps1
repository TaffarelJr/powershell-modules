#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one gist by id, whose file name has an underscore and an extension
$fake = New-FakeGitHubCli `
    -Output @('{"id":"bcd1234567890abcdef0","created_at":"2026-01-02T03:04:05Z","description":"notes","files":{"hello_world.py":{"filename":"hello_world.py","raw_url":"https://raw/x","truncated":false,"content":"hi"}}}')
try {
    # Act
    $gist = Get-GitHubGist -Id 'bcd1234567890abcdef0'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists/bcd1234567890abcdef0') -Actual $call.Arguments `
        -Message 'The id is embedded directly in the endpoint path'
    Assert-Equal -Expected 'notes' -Actual $gist.Description `
        -Message 'The gist comes back as one object with PascalCase fields'
    Assert-That -Condition ($gist.CreatedAt -is [datetime]) -Message 'including the ones GitHub names in snake_case'
    Assert-Equal -Expected @('hello_world.py') -Actual @($gist.Files.PSBase.Keys) `
        -Message "Files is keyed by each file's real name, not a re-cased one"
    Assert-Equal -Expected 'hi' -Actual $gist.Files.'hello_world.py'.Content `
        -Message "so a file is found by the name it has in the gist, with its content"
    Assert-Equal -Expected 'hi' -Actual $gist.Files['hello_world.py'].Content -Message 'by member access or by index'
    Assert-Equal -Expected 'https://raw/x' -Actual $gist.Files.'hello_world.py'.RawUrl `
        -Message 'while what each file holds is PascalCase as usual'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file too large for GitHub to send inline
$fake = New-FakeGitHubCli `
    -Output @('{"id":"bcd1234567890abcdef0","files":{"big.log":{"filename":"big.log","truncated":true,"raw_url":"https://raw/big","content":"start"}}}')
try {
    # Act
    $gist = Get-GitHubGist -Id 'bcd1234567890abcdef0'

    # Assert
    Assert-Equal -Expected $true -Actual $gist.Files.'big.log'.Truncated -Message 'A truncated file says so'
    Assert-Equal -Expected 'https://raw/big' -Actual $gist.Files.'big.log'.RawUrl `
        -Message 'and carries the URL of all of it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the id given as a URL, as a browser's address bar shows it
$fake = New-FakeGitHubCli -Output @('{"id":"bcd1234567890abcdef0"}')
try {
    # Act
    Get-GitHubGist -Id 'https://gist.github.com/me/bcd1234567890abcdef0#file-notes-md' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists/bcd1234567890abcdef0') -Actual $call.Arguments `
        -Message 'A gist URL, fragment and all, is reduced to its bare id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the URLs the README's usage and this function's example give
$readme = Get-Content -LiteralPath (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/README.md') -Raw
$help = (Get-Help Get-GitHubGist -Full).examples.example[0].code
$pattern = "Get-GitHubGist -Id '([^']+)'"
$urls = @(
    [regex]::Match($readme, $pattern).Groups[1].Value
    [regex]::Match($help, $pattern).Groups[1].Value
)
$fake = New-FakeGitHubCli -Output @('{"id":"0123456789abcdef0123456789abcdef"}')
try {
    # Act
    foreach ($url in $urls) {
        Get-GitHubGist -Id $url | Out-Null
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('gists/0123456789abcdef0123456789abcdef', 'gists/0123456789abcdef0123456789abcdef') `
        -Actual @($calls.ForEach({ $_.Arguments[1] })) `
        -Message 'The documented URLs name a gist the function reads'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - ids from the pipeline, as another gist command's output gives them
$fake = New-FakeGitHubCli -Output @('{"id":"x"}')
try {
    # Act
    [PSCustomObject]@{ Id = 'bcd1234567890abcdef0' } | Get-GitHubGist | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists/bcd1234567890abcdef0') -Actual $call.Arguments `
        -Message 'The Id property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - something that is not a gist
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubGist -Id 'abc/../x'
    } -MessageLike "*'abc/../x' is not a gist: give its id or URL, or a gist object." `
        -Message 'A value that is not an id or a gist URL is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing gists, one of which has a file with an underscore in its name
$fake = New-FakeGitHubCli -Output @('[[{"id":"a","files":{"my_notes.md":{"raw_url":"u"}}},{"id":"b","files":{}}]]')
try {
    # Act
    $gists = @(Get-GitHubGist -List)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'gists?per_page=100', '--paginate', '--slurp') -Actual $call.Arguments `
        -Message 'Listing asks for every page, each the largest the gists collection gives'
    Assert-Equal -Expected @('a', 'b') -Actual @($gists.ForEach('Id')) `
        -Message 'Every listed gist is returned, one at a time'
    Assert-Equal -Expected @('my_notes.md') -Actual @($gists[0].Files.PSBase.Keys) `
        -Message "and each one's Files keeps its real file names"
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two pages, as gh's --slurp gives them
$fake = New-FakeGitHubCli -Output @('[[{"id":"a"}],[{"id":"b"},{"id":"c"}]]')
try {
    # Act
    $gists = @(Get-GitHubGist -List)

    # Assert
    Assert-Equal -Expected @('a', 'b', 'c') -Actual @($gists.ForEach('Id')) `
        -Message 'The pages come back as one flat list'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a list of one gist
$fake = New-FakeGitHubCli -Output @('[[{"id":"a"}]]')
try {
    # Act
    $gists = Get-GitHubGist -List

    # Assert
    Assert-That -Condition ($gists -isnot [array]) `
        -Message 'A single listed gist is written as that one object, not wrapped in an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an account with no gists
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    $gists = @(Get-GitHubGist -List)

    # Assert
    Assert-Equal -Expected 0 -Actual $gists.Count -Message 'No gists writes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file whose content, and a description, that are timestamps
$stamp = '2026-01-02T03:04:05.1234567+05:00'
$fake = New-FakeGitHubCli `
    -Output @("{`"id`":`"bcd1234567890abcdef0`",`"description`":`"$stamp`",`"files`":{`"last-run.txt`":{`"content`":`"$stamp`"}}}")
try {
    # Act
    $gist = Get-GitHubGist -Id 'bcd1234567890abcdef0'

    # Assert
    Assert-Equal -Expected $stamp -Actual $gist.Files['last-run.txt'].Content `
        -Message 'Content that looks like a date stays the text in the file'
    Assert-Equal -Expected $stamp -Actual $gist.Description -Message 'and so does such a description'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - file names that differ only in case, and one a PowerShell object
# reserves as a member name
$fake = New-FakeGitHubCli `
    -Output @('{"id":"bcd1234567890abcdef0","files":{"README.md":{"content":"upper"},"readme.md":{"content":"lower"},"PSObject":{"content":"p"}}}')
try {
    # Act
    $gist = Get-GitHubGist -Id 'bcd1234567890abcdef0'

    # Assert
    Assert-Equal -Expected @('README.md', 'readme.md', 'PSObject') -Actual @($gist.Files.PSBase.Keys) `
        -Message 'Every file is kept, under its own name, in order'
    Assert-Equal -Expected 'lower' -Actual $gist.Files['readme.md'].Content `
        -Message 'and a name is matched with its case'
    Assert-Equal -Expected 'p' -Actual $gist.Files['PSObject'].Content -Message 'and a reserved one is an ordinary name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gist with several files
$fake = New-FakeGitHubCli `
    -Output @('{"id":"bcd1234567890abcdef0","files":{"a.txt":{"filename":"a.txt"},"b.txt":{"filename":"b.txt"},"c.txt":{"filename":"c.txt"}}}')
try {
    # Act
    $gist = Get-GitHubGist -Id 'bcd1234567890abcdef0'
    $names = @($gist.Files.PSBase.Values | ForEach-Object Filename)

    # Assert
    Assert-Equal -Expected @('a.txt', 'b.txt', 'c.txt') -Actual $names `
        -Message 'Files.PSBase.Values gives each file object in turn'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files named like the members of the file list
$fake = New-FakeGitHubCli `
    -Output @('{"id":"bcd1234567890abcdef0","files":{"Keys":{"filename":"Keys"},"Values":{"filename":"Values"},"a.txt":{"filename":"a.txt"}}}')
try {
    # Act
    $gist = Get-GitHubGist -Id 'bcd1234567890abcdef0'
    $names = @($gist.Files.PSBase.Values | ForEach-Object Filename)

    # Assert
    Assert-Equal -Expected @('Keys', 'Values', 'a.txt') -Actual @($gist.Files.PSBase.Keys) `
        -Message 'Files.PSBase.Keys gives every name, Keys and Values among them'
    Assert-Equal -Expected @('Keys', 'Values', 'a.txt') -Actual $names `
        -Message 'and Files.PSBase.Values every file object'
    Assert-Equal -Expected 'Values' -Actual $gist.Files['Values'].Filename `
        -Message 'while the file named Values is read by its name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gist with more files than GitHub lists
$fake = New-FakeGitHubCli `
    -Output @('{"id":"bcd1234567890abcdef0","truncated":true,"files":{"a.txt":{"filename":"a.txt"}}}')
try {
    # Act
    $warnings = @(Get-WarningOutput -ScriptBlock { Get-GitHubGist -Id 'bcd1234567890abcdef0' | Out-Null })

    # Assert
    Assert-Equal `
        -Expected @('Gist bcd1234567890abcdef0 has more than 300 files, and GitHub lists only the first 300 in Files: clone it with Copy-GitHubGist for every file.') `
        -Actual $warnings `
        -Message 'A gist whose file list GitHub cut short warns so'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a list holding such a gist
$fake = New-FakeGitHubCli -Output @('[[{"id":"a","truncated":false},{"id":"b","truncated":true}]]')
try {
    # Act
    $warnings = @(Get-WarningOutput -ScriptBlock { Get-GitHubGist -List | Out-Null })

    # Assert
    Assert-Equal `
        -Expected @('Gist b has more than 300 files, and GitHub lists only the first 300 in Files: clone it with Copy-GitHubGist for every file.') `
        -Actual $warnings `
        -Message 'A listed gist cut short warns too, and only that one'
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
        Get-GitHubGist -Id 'bcd1234567890abcdef0'
    } -MessageLike '*Reading gist bcd1234567890abcdef0 failed: gh api gists/bcd1234567890abcdef0 (exit 1)*Not Found (HTTP 404)*' `
        -Message 'A gist GitHub cannot find throws, naming it and with GitHub''s message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects that carry no text Id, as another command might give them
$fake = New-FakeGitHubCli -Output @('{"id":"x"}')
try {
    # Act
    [PSCustomObject]@{ HtmlUrl = 'https://gist.github.com/me/bcd1234567890abcdef0' } | Get-GitHubGist | Out-Null
    [PSCustomObject]@{
        Id = 12345
        Url = 'https://api.github.com/gists/fedcba9876543210fedc'
    } | Get-GitHubGist | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'gists/bcd1234567890abcdef0') -Actual $calls[0].Arguments `
        -Message 'A piped object is read by its HtmlUrl, not turned into its text'
    Assert-Equal -Expected @('api', 'gists/fedcba9876543210fedc') -Actual $calls[1].Arguments `
        -Message 'or by its Url, when its Id is not a gist id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a lookup that came back empty
Assert-Throws -ScriptBlock {
    Get-GitHubGist -Id $null
} -MessageLike "*Cannot bind argument to parameter 'Id' because it is null*" `
    -Message 'A $null gist is refused, not read as some other gist'

exit (Complete-TestRun)
