#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a repository, and the name each shows
$forms = @(
    @{ Given = 'o/r'; Expected = 'o/r'; Message = 'OWNER/REPO is shown as it is' }
    @{ Given = ' o/r '; Expected = 'o/r'; Message = 'without surrounding spaces' }
    @{ Given = 'o/r.git'; Expected = 'o/r'; Message = 'A trailing .git is dropped' }
    @{ Given = 'o/r.git.git'; Expected = 'o/r'; Message = 'and so is each of several' }
    @{ Given = 'o/r//'; Expected = 'o/r'; Message = 'and so are trailing slashes' }
    @{ Given = 'o/my.git-tools'; Expected = 'o/my.git-tools'; Message = 'A name holding .git inside keeps it' }
    @{ Given = 'o/.git'; Expected = 'o/.git'; Message = 'and a name that is only .git is not emptied' }
    @{ Given = 'github.com/o/r'; Expected = 'o/r'; Message = 'The github.com host is left out' }
    @{ Given = 'GitHub.COM/o/r'; Expected = 'o/r'; Message = 'in any case' }
    @{ Given = 'www.github.com/o/r'; Expected = 'o/r'; Message = 'and a subdomain of github.com is github.com' }
    @{ Given = 'ghe.example.com/o/r.git/'; Expected = 'ghe.example.com/o/r'; Message = 'Another host is shown' }
    @{
        Given = 'ghe.example.com:8443/o/r'
        Expected = 'ghe.example.com:8443/o/r'
        Message = 'A port in HOST:PORT text stays part of the host'
    }
    @{ Given = 'https://github.com/o/r'; Expected = 'o/r'; Message = 'A URL names the same repository as its text' }
    @{ Given = 'http://ghe.example.com/o/r/'; Expected = 'ghe.example.com/o/r'; Message = 'an http: one with its host' }
    @{
        Given = 'https://ghe.example.com:8443/o/r'
        Expected = 'ghe.example.com/o/r'
        Message = 'A URL''s port is dropped, as gh drops it'
    }
    @{
        Given = 'https://github.com/o/r/issues/12?x=1#top'
        Expected = 'o/r'
        Message = 'An item''s path, a query, and a fragment are dropped'
    }
    @{ Given = 'https://www.github.com/o/r.git'; Expected = 'o/r'; Message = 'A URL on www.github.com is github.com' }
    @{
        Given = 'ssh://git@ghe.example.com:2222/o/r.git'
        Expected = 'ghe.example.com/o/r'
        Message = 'An ssh: URL drops its user and port'
    }
    @{ Given = 'git://github.com/o/r.git'; Expected = 'o/r'; Message = 'a git: URL' }
    @{ Given = 'git+ssh://git@github.com/o/r'; Expected = 'o/r'; Message = 'a git+ssh: URL' }
    @{ Given = 'git+https://ghe.example.com/o/r.git'; Expected = 'ghe.example.com/o/r'; Message = 'a git+https: URL' }
    @{ Given = 'git@github.com:o/r.git'; Expected = 'o/r'; Message = 'The SSH form drops its git user' }
    @{ Given = 'git@ghe.example.com:o/r'; Expected = 'ghe.example.com/o/r'; Message = 'and keeps another host' }
    @{
        Given = 'git@ghe.example.com:8443:o/r'
        Expected = 'ghe.example.com/8443:o/r'
        Message = 'and reads its owner, as gh does, from the first colon to the last slash'
    }
    @{
        Given = 'https://u:LEAK a@github.com/o/r'
        Expected = 'o/r'
        Message = 'A password holding a space is hidden whole'
    }
    @{
        Given = 'https://us er:LEAK@github.com/o/r'
        Expected = 'o/r'
        Message = 'and so is a user name holding one'
    }
    @{ Given = @('o/r'); Expected = 'o/r'; Message = 'An array of one repository is read as that repository' }
    @{
        Given = [PSCustomObject]@{ Url = 'https://x-access-token:LEAK@ghe.example.com/o/r'; NameWithOwner = 'o/r' }
        Expected = 'ghe.example.com/o/r'
        Message = 'A repository object is read by its Url, without the token it carries'
    }
    @{
        Given = [PSCustomObject]@{ Url = 'https://github.com/o/r/issues/12'; NameWithOwner = 'o/r' }
        Expected = 'o/r'
        Message = 'and an issue''s Url is passed over for its NameWithOwner'
    }
    @{
        Given = [PSCustomObject]@{ url = 'https://api.github.com/repos/o/r'; html_url = 'https://github.com/o/r' }
        Expected = 'o/r'
        Message = 'as a raw API object''s REST url is for its html_url'
    }
    @{ Given = [PSCustomObject]@{ FullName = 'o/r' }; Expected = 'o/r'; Message = 'A search result by its FullName' }
    @{ Given = @{ nameWithOwner = 'o/r.git' }; Expected = 'o/r'; Message = 'A hashtable by its keys, in any case' }
)

# Act / Assert
foreach ($form in $forms) {
    Assert-Equal -Expected $form.Expected -Actual (Format-GitHubRepositoryName -Repository $form.Given) `
        -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text that names no repository, shown without its credential
$unread = @(
    @{ Given = 'garbage'; Expected = 'garbage'; Message = 'A bare word is shown as it is' }
    @{ Given = '--web'; Expected = '--web'; Message = 'and so is a flag, which the converter refuses' }
    @{ Given = ''; Expected = ''; Message = 'and empty text' }
    @{ Given = ' a/b/c/d '; Expected = 'a/b/c/d'; Message = 'Too many parts are shown trimmed' }
    @{
        Given = 'https://u:LEAK@github.com/o'
        Expected = 'https://***@github.com/o'
        Message = 'A URL without a repository is shown with its credential hidden'
    }
    @{
        Given = 'https://u:LEAK@github.com/o?token=LEAK#LEAK'
        Expected = 'https://***@github.com/o'
        Message = 'and without its query and fragment'
    }
    @{
        Given = 'HTTPS://x-access-token:LEAK@github.com/o/r.git'
        Expected = 'HTTPS://***@github.com/o/r'
        Message = 'An upper-case scheme, which gh does not read, still loses its credential and its .git'
    }
    @{
        Given = 'user:LEAK@ghe.example.com/o/r'
        Expected = '***@ghe.example.com/o/r'
        Message = 'and so does text without a scheme'
    }
    @{
        Given = 'LEAK@ghe.example.com:8443/o/r'
        Expected = '***@ghe.example.com:8443/o/r'
        Message = 'even a token alone before a host and a slash'
    }
    @{
        Given = 'LEAK@[::1]:22/o/r/'
        Expected = '***@[::1]:22/o/r'
        Message = 'or before a bracketed host'
    }
    @{
        Given = 'org-123@github.com:o/r'
        Expected = 'org-123@github.com:o/r'
        Message = 'An SSH form''s user is not a credential and is kept'
    }
    @{
        Given = 'https://u:LEAK@h.example/o/r https://v:LEAK@ghe.example.com/x/y'
        Expected = 'https://***@h.example/o/r https://***@ghe.example.com/x/y'
        Message = 'Each of several URLs is cleaned on its own'
    }
    @{
        Given = 'https://u:LEAK@github.com/o/r/blob/main/a@b'
        Expected = 'https://***@b'
        Message = 'An @ later in the text hides everything up to it, so nothing is left to read as a repository'
    }
    @{ Given = @('o/a', 'o/b'); Expected = 'o/a o/b'; Message = 'A list of several is shown as text' }
    @{ Given = @(); Expected = ''; Message = 'and an empty one as nothing' }
    @{
        Given = [PSCustomObject]@{ Url = 'https://u:LEAK@github.com/o/r/issues/1' }
        Expected = '@{Url=https://***@github.com/o/r/issues/1}'
        Message = 'An object with nothing to read shows its text without the credential'
    }
)

# Act / Assert
foreach ($case in $unread) {
    Assert-Equal -Expected $case.Expected -Actual (Format-GitHubRepositoryName -Repository $case.Given) `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every URL form crossed with every credential shape
$schemes = @(
    @{ Prefix = 'https://'; OnGitHub = 'o/r'; OnEnterprise = 'ghe.example.com/o/r' }
    @{ Prefix = 'http://'; OnGitHub = 'o/r'; OnEnterprise = 'ghe.example.com/o/r' }
    @{ Prefix = 'ssh://'; OnGitHub = 'o/r'; OnEnterprise = 'ghe.example.com/o/r' }
    @{ Prefix = 'git://'; OnGitHub = 'o/r'; OnEnterprise = 'ghe.example.com/o/r' }
    @{ Prefix = 'git+ssh://'; OnGitHub = 'o/r'; OnEnterprise = 'ghe.example.com/o/r' }
    @{ Prefix = 'git+https://'; OnGitHub = 'o/r'; OnEnterprise = 'ghe.example.com/o/r' }
    @{
        Prefix = 'HTTPS://'
        OnGitHub = 'HTTPS://***@github.com/o/r'
        OnEnterprise = 'HTTPS://***@ghe.example.com:8443/o/r'
    }
    @{
        Prefix = 'Git+SSH://'
        OnGitHub = 'Git+SSH://***@github.com/o/r'
        OnEnterprise = 'Git+SSH://***@ghe.example.com:8443/o/r'
    }
    @{ Prefix = ''; OnGitHub = '***@github.com/o/r'; OnEnterprise = '***@ghe.example.com:8443/o/r' }
)
$userInfos = @(
    'USERu:LEAKp'
    'USER12345:LEAK67890'
    'x-access-token:LEAKghs_0123'
    'USERa:USERb:LEAKc'
    'USERme@USERexample.com:LEAKp'
    'USERu:LEAKa@LEAKb'
    'USERu:LEAKa/LEAKb'
    'USERu:LEAKa%40LEAKb%2F'
    'USERu:LEAKa#LEAKb?LEAKc'
    'USERu:LEAKa:LEAKb'
    'USERu:LEAKa@LEAKb/LEAKc:LEAKd%25LEAKe'
    'USERu:'
    ':LEAKonly'
    'LEAKghp_token'
    'USERme@USERexample.com'
)
$leaks = foreach ($scheme in $schemes) {
    foreach ($userInfo in $userInfos) {
        @{
            Given = "$($scheme.Prefix)$userInfo@github.com/o/r"
            Expected = $scheme.OnGitHub
        }
        @{
            Given = "$($scheme.Prefix)$userInfo@ghe.example.com:8443/o/r"
            Expected = $scheme.OnEnterprise
        }
    }
}

# Act / Assert
foreach ($leak in $leaks) {
    $shown = Format-GitHubRepositoryName -Repository $leak.Given
    Assert-Equal -Expected $leak.Expected -Actual $shown -Message "'$($leak.Given)' is shown without its credential"
    Assert-That -Condition ($shown -cnotmatch 'LEAK|USER') -Message "and no part of it survives from '$($leak.Given)'"
}

#───────────────────────────────────────────────────────────────────────────────
# Act - several URLs joined by a comma, which gh would never read
$joined = Format-GitHubRepositoryName -Repository 'https://u:LEAK@github.com/o/r,https://v:LEAK@ghe.example.com/x/y'
$hidden = $joined -cnotmatch 'LEAK'

# Assert
Assert-That -Condition $hidden -Message 'Every URL in one word loses its credential'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what the function shows, to be formatted again
$shownOnce = @(
    foreach ($row in $forms + $unread + $leaks) {
        Format-GitHubRepositoryName -Repository $row.Given
    }
)

# Act / Assert
foreach ($shown in $shownOnce) {
    Assert-Equal -Expected $shown -Actual (Format-GitHubRepositoryName -Repository $shown) `
        -Message "'$shown' formatted again is unchanged"
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - one issue's repository named the same way however it is given
Assert-Equal -Expected (Format-GitHubRepositoryName -Repository 'o/r') `
    -Actual (Format-GitHubRepositoryName -Repository 'https://github.com/o/r') `
    -Message 'A URL and OWNER/REPO for the same repository give the same name'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - $null names nothing to show
Assert-Throws -ScriptBlock {
    Format-GitHubRepositoryName -Repository $null
} -MessageLike "*Cannot bind argument to parameter 'Repository' because it is null*" `
    -Message '$null is refused by PowerShell, as for any mandatory parameter'

exit (Complete-TestRun)
