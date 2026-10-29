#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force `
    -PassThru

$id = 'aa5a315d61ae9438b18d'
$id32 = '0123456789abcdef0123456789abcdef'
$sha = '0123456789abcdef0123456789abcdef01234567'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every form that names a gist, and the id each one holds
$forms = @(
    @{ Given = 'bcd1234567890abcdef0'; Expected = 'bcd1234567890abcdef0'; Message = 'A bare id is returned as it is' }
    @{ Given = 'AbC123xyZ'; Expected = 'AbC123xyZ'; Message = 'whatever its case' }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0'
        Expected = 'bcd1234567890abcdef0'
        Message = 'A URL with its owner gives the id after it'
    }
    @{ Given = "https://gist.github.com/$id"; Expected = $id; Message = 'A URL without an owner gives the id' }
    @{ Given = "https://gist.github.com/$id32"; Expected = $id32; Message = 'and so does one with a 32-digit id' }
    @{
        Given = "https://gist.github.com/$($id.ToUpperInvariant())"
        Expected = $id.ToUpperInvariant()
        Message = 'in either case'
    }
    @{
        Given = 'https://gist.github.com/1234567'
        Expected = '1234567'
        Message = 'and one with the number of an old gist'
    }
    @{
        Given = 'http://gist.github.com/some-user/bcd1234567890abcdef0'
        Expected = 'bcd1234567890abcdef0'
        Message = 'An http URL and an owner with a dash work too'
    }
    @{
        Given = 'HTTPS://GIST.GITHUB.COM/me/bcd1234567890abcdef0'
        Expected = 'bcd1234567890abcdef0'
        Message = 'An upper-case scheme and host work too'
    }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0#file-notes-md'
        Expected = 'bcd1234567890abcdef0'
        Message = 'A #file- fragment a browser adds is dropped'
    }
    @{ Given = "https://gist.github.com/$id#file-notes-md"; Expected = $id; Message = 'also without an owner' }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0?permalink_comment_id=7'
        Expected = 'bcd1234567890abcdef0'
        Message = 'A query string is dropped'
    }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0/raw/notes.md'
        Expected = 'bcd1234567890abcdef0'
        Message = 'A /raw path is dropped'
    }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0/'
        Expected = 'bcd1234567890abcdef0'
        Message = 'A trailing slash is dropped'
    }
    @{ Given = "https://gist.github.com/$id/"; Expected = $id; Message = 'also without an owner' }
    @{
        Given = "https://gist.github.com/$id/raw"
        Expected = $id
        Message = 'An owner-less /raw URL gives the id, not raw'
    }
    @{ Given = "https://gist.github.com/$id/raw/file.txt"; Expected = $id; Message = 'and one naming a file' }
    @{
        Given = "https://gist.github.com/$id/revisions"
        Expected = $id
        Message = 'An owner-less /revisions URL gives the id'
    }
    @{ Given = "https://gist.github.com/$id/forks"; Expected = $id; Message = 'An owner-less /forks URL gives the id' }
    @{
        Given = "https://gist.github.com/$id/stargazers"
        Expected = $id
        Message = 'An owner-less /stargazers URL gives the id'
    }
    @{
        Given = "https://gist.github.com/$id/$sha"
        Expected = $id
        Message = 'An owner-less revision URL gives the id, not the revision'
    }
    @{ Given = "https://gist.github.com/me/$id/$sha"; Expected = $id; Message = 'and so does one with an owner' }
    @{
        Given = "https://gist.github.com/$id/$($sha.ToUpperInvariant())"
        Expected = $id
        Message = 'and one whose revision is upper-case'
    }
    @{
        Given = "https://gist.github.com/$id.git"
        Expected = $id
        Message = 'The clone URL GitHub gives as git_pull_url gives the id'
    }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0.git'
        Expected = 'bcd1234567890abcdef0'
        Message = 'and so does one with an owner, whose owner is not taken for the id'
    }
    @{ Given = "git@gist.github.com:$id32.git"; Expected = $id32; Message = 'The SSH clone URL gives the id' }
    @{ Given = "git@gist.github.com:$id"; Expected = $id; Message = 'with or without its .git' }
    @{
        Given = "https://gist.ghe.example.com/me/$id32"
        Expected = $id32
        Message = 'An enterprise server''s gist. host is read like gist.github.com'
    }
    @{ Given = "git@gist.ghe.example.com:$id.git"; Expected = $id; Message = 'and so is its SSH clone URL' }
    @{ Given = [uri]"https://gist.github.com/$id"; Expected = $id; Message = 'A [uri] is read as its text' }
    @{ Given = [uri]$id; Expected = $id; Message = 'a relative one, holding a bare id, too' }
    @{ Given = [uri]"git@gist.github.com:$id.git"; Expected = $id; Message = 'and one holding the SSH clone URL' }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0.js'
        Expected = 'bcd1234567890abcdef0'
        Message = 'The script embed URL gives the id'
    }
    @{ Given = "https://gist.github.com/$id.js"; Expected = $id; Message = 'also without an owner' }
    @{
        Given = 'https://gist.github.com/me/bcd1234567890abcdef0.pibb'
        Expected = 'bcd1234567890abcdef0'
        Message = 'and so does the pibb embed URL'
    }
    @{
        Given = "https://gist.githubusercontent.com/me/bcd1234567890abcdef0/raw/$sha/notes.md"
        Expected = 'bcd1234567890abcdef0'
        Message = 'A raw file URL gives the id'
    }
    @{
        Given = 'https://api.github.com/gists/bcd1234567890abcdef0'
        Expected = 'bcd1234567890abcdef0'
        Message = 'The API URL GitHub gives as url gives the id'
    }
    @{
        Given = "https://api.github.com/gists/bcd1234567890abcdef0/$sha"
        Expected = 'bcd1234567890abcdef0'
        Message = 'and so does an API URL of one revision'
    }
    @{
        Given = 'https://ghe.example/gist/me/bcd1234567890abcdef0'
        Expected = 'bcd1234567890abcdef0'
        Message = 'An enterprise server gist URL gives the id'
    }
    @{
        Given = 'https://ghe.example/gist/bcd1234567890abcdef0/raw'
        Expected = 'bcd1234567890abcdef0'
        Message = 'also without an owner'
    }
    @{
        Given = 'https://ghe.example/api/v3/gists/bcd1234567890abcdef0'
        Expected = 'bcd1234567890abcdef0'
        Message = 'and so does its API URL'
    }
    @{ Given = 1234567; Expected = '1234567'; Message = 'A number is the id of an old gist' }
    @{ Given = [long]5000000001; Expected = '5000000001'; Message = 'a long one too' }
    @{ Given = [int16]5; Expected = '5'; Message = 'and a short one' }
    @{ Given = [uint64]5; Expected = '5'; Message = 'and an unsigned one' }
    @{ Given = [byte]7; Expected = '7'; Message = 'and a byte' }
    @{
        Given = [PSCustomObject]@{ Id = 'bcd1234567890abcdef0'; HtmlUrl = 'https://gist.github.com/me/other' }
        Expected = 'bcd1234567890abcdef0'
        Message = 'An object is read by its Id first'
    }
    @{
        Given = [PSCustomObject]@{ HtmlUrl = 'https://gist.github.com/me/bcd1234567890abcdef0' }
        Expected = 'bcd1234567890abcdef0'
        Message = 'then by its HtmlUrl'
    }
    @{
        Given = @{ Url = 'https://api.github.com/gists/bcd1234567890abcdef0' }
        Expected = 'bcd1234567890abcdef0'
        Message = 'then by its Url, a hashtable too'
    }
    @{
        Given = @{ Keys = 'x'; Id = 'bcd1234567890abcdef0' }
        Expected = 'bcd1234567890abcdef0'
        Message = 'even one with an entry named Keys'
    }
    @{
        Given = [PSCustomObject]@{ Id = 12345; Url = 'https://api.github.com/gists/bcd1234567890abcdef0' }
        Expected = 'bcd1234567890abcdef0'
        Message = 'An Id that is not text is not a gist id, so the Url is read'
    }
    @{
        Given = @('bcd1234567890abcdef0')
        Expected = 'bcd1234567890abcdef0'
        Message = 'A list of one id is that id'
    }
    @{
        Given = @([PSCustomObject]@{ HtmlUrl = 'https://gist.github.com/me/bcd1234567890abcdef0' })
        Expected = 'bcd1234567890abcdef0'
        Message = 'A list of one gist, as @(Get-GitHubGist ...) gives, is that gist'
    }
    @{ Given = @(1234567); Expected = '1234567'; Message = 'A list of one number is that number' }
)

# Act / Assert
foreach ($form in $forms) {
    $actual = & $module { param($i) ConvertTo-GitHubGistId -Id $i } $form.Given
    Assert-Equal -Expected $form.Expected -Actual $actual -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are not a gist, and why each is refused
$refused = @(
    @{
        Given = '-bcd1234567890abcdef0'
        Message = 'An id that starts with a dash is refused, so gh never reads it as an option'
    }
    @{ Given = '--yes'; Message = 'as is a flag' }
    @{ Given = 'abc/def'; Message = 'A path that is not a URL is refused, not cut short' }
    @{ Given = 'abc 123'; Message = 'An id with a space is refused' }
    @{ Given = "$id`n"; Message = 'An id with a newline after it is refused, not passed on with the newline' }
    @{ Given = "`u{212A}"; Message = 'A letter beyond ASCII that matches K without case is refused' }
    @{ Given = 'a.txt'; Message = 'A file name is refused' }
    @{
        Given = 'https://example.com/me/bcd1234567890abcdef0'
        Message = 'A URL on another host that is not a gist URL is refused'
    }
    @{ Given = 'https://gist-github.com/me/bcd1234567890abcdef0'; Message = 'A look-alike host is refused' }
    @{ Given = 'https://gist.github.com/'; Message = 'A URL with no id is refused' }
    @{
        Given = 'https://gist.github.com/me/'
        Message = 'and one with an owner and no id, whose owner is not taken for the id'
    }
    @{ Given = 'https://gist.github.com/-me/-abc'; Message = 'and one whose id starts with a dash' }
    @{ Given = 'https://gist.github.com/starred'; Message = 'A page of GitHub''s own on the gist host is refused' }
    @{ Given = 'https://gist.github.com/discover'; Message = 'as is discover' }
    @{ Given = 'https://gist.github.com/mine'; Message = 'and mine' }
    @{
        Given = 'https://gist.github.com/TaffarelJr'
        Message = 'A user''s page is refused, as no gist id holds letters past f'
    }
    @{
        Given = 'https://gist.github.com/deadbeef'
        Message = 'and so is a hexadecimal name that is not an id''s length'
    }
    @{ Given = 'https://gist.github.com/abc'; Message = 'as is abc' }
    @{ Given = 'https://ghe.example/gist/TaffarelJr'; Message = 'and a user''s page on an enterprise server' }
    @{ Given = 'https://gist.github.com/me/forked'; Message = 'A user''s forked page is refused' }
    @{ Given = 'https://gist.github.com/me/secret'; Message = 'and their secret page' }
    @{ Given = 'https://gist.github.com/me/Starred'; Message = 'and their starred page, in any case' }
    @{ Given = 'https://gist.github.com/me/public'; Message = 'and their public page' }
    @{ Given = 'git@github.com:o/r.git'; Message = 'An SSH URL of a repository is refused' }
    @{ Given = "https://gist./me/$id"; Message = 'A gist. host with nothing after it is refused' }
    @{
        Given = "https://gist.github.com.evil.com/me/$id"
        Message = 'and so is one that only starts like github.com''s'
    }
    @{ Given = "https://gist.-x.example/me/$id"; Message = 'and one whose label starts with a dash' }
    @{ Given = "git@gist.:$id.git"; Message = 'and an SSH URL with no host after gist.' }
    @{ Given = "git@gist.github.com.evil.com:$id.git"; Message = 'or one that only starts like github.com''s' }
    @{ Given = 'git@gist.github.com:me/stars.git'; Message = 'and so is an SSH URL on the gist host that holds no id' }
    @{
        Given = 'https://gist.github.com/me/stars'
        Message = 'and any other page of theirs, as its name is not an id''s shape'
    }
    @{ Given = 'https://gist.github.com/auth/github'; Message = 'and one of GitHub''s own two-part pages' }
    @{
        Given = 'https://gist.github.com/me/abc123'
        Message = 'and an owner''s page whose second part is not an id''s length'
    }
    @{ Given = 'https://api.github.com/gists/starred'; Message = 'A list endpoint of the API is refused' }
    @{ Given = 'https://api.github.com/repos/o/r'; Message = 'An API URL that is not a gist is refused' }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module { param($i) ConvertTo-GitHubGistId -Id $i } $case.Given
    } -MessageLike "*'$([WildcardPattern]::Escape($case.Given))' is not a gist: give its id or URL, or a gist object." `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - an object whose Url is not a gist
Assert-Throws -ScriptBlock {
    & $module { param($i) ConvertTo-GitHubGistId -Id $i } ([PSCustomObject]@{ Url = 'https://github.com/o/r' })
} -MessageLike "*'https://github.com/o/r' is not a gist: give its id or URL, or a gist object." `
    -Message 'An object whose Url is not a gist is refused, naming that Url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects with nothing to read a gist from
$objects = @(
    @{
        Given = [PSCustomObject]@{ Name = 'x' }
        Type = 'PSCustomObject'
        Message = 'An object with no Id, HtmlUrl or Url is refused'
    }
    @{
        Given = [PSCustomObject]@{ Id = 12345 }
        Type = 'PSCustomObject'
        Message = 'as is one whose only Id is not text'
    }
    @{ Given = $true; Type = 'Boolean'; Message = 'A true is not the id True' }
    @{ Given = [decimal]5; Type = 'Decimal'; Message = 'and a decimal is not a whole number, so not an id' }
    @{ Given = [double]5; Type = 'Double'; Message = 'nor is a double' })

# Act / Assert
foreach ($case in $objects) {
    Assert-Throws -ScriptBlock {
        & $module { param($i) ConvertTo-GitHubGistId -Id $i } $case.Given
    } -MessageLike "*A gist object needs an Id, an HtmlUrl, or a Url, and this one has none: $($case.Type).*" `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a list where one gist belongs
Assert-Throws -ScriptBlock {
    & $module { param($i) ConvertTo-GitHubGistId -Id $i } @('a', 'b')
} -MessageLike '*Give one gist at a time, not a list of 2; pipe them to name several.*' `
    -Message 'A list is refused, not read as one gist'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a list of one that holds nothing
Assert-Throws -ScriptBlock {
    & $module { param($i) ConvertTo-GitHubGistId -Id $i } @($null)
} -MessageLike '*A gist was given, but it is $null: give its id or URL, or a gist object.*' `
    -Message 'A list of one $null is the $null, which is refused'

exit (Complete-TestRun)
