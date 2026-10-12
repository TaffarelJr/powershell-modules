#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force `
    -PassThru

function ConvertTo-SearchRepository {
    param($Repository)

    return & $module {
        param($r)
        ConvertTo-GitHubSearchRepository -Repository $r
    } $Repository
}

$env:GH_HOST = $null

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every form of a github.com repository, with GH_HOST not set
$rows = @(
    @{ Value = 'cli/cli'; Expected = 'cli/cli'; Message = 'OWNER/REPO comes back as given' }
    @{ Value = 'Cli/CLI'; Expected = 'Cli/CLI'; Message = 'in its own case' }
    @{ Value = ' cli/cli '; Expected = 'cli/cli'; Message = 'trimmed' }
    @{ Value = 'cli/cli.git'; Expected = 'cli/cli'; Message = 'without .git' }
    @{
        Value = 'github.com/cli/cli'
        Expected = 'cli/cli'
        Message = 'HOST/OWNER/REPO on github.com is cut down to OWNER/REPO'
    }
    @{
        Value = 'GitHub.COM/cli/cli/'
        Expected = 'cli/cli'
        Message = 'whatever the host''s case, and without a trailing slash'
    }
    @{ Value = 'https://github.com/cli/cli'; Expected = 'cli/cli'; Message = 'and so is a URL' }
    @{ Value = 'https://GitHub.COM/cli/cli'; Expected = 'cli/cli'; Message = 'whatever the host''s case' }
    @{
        Value = 'https://www.github.com/cli/cli'
        Expected = 'cli/cli'
        Message = 'and on www.github.com, which is github.com'
    }
    @{
        Value = 'gist.github.com/cli/cli'
        Expected = 'cli/cli'
        Message = 'and on any other subdomain of github.com, as gh reads it'
    }
    @{
        Value = 'api.github.com/cli/cli'
        Expected = 'cli/cli'
        Message = 'api.github.com included, when it is no REST URL'
    }
    @{ Value = 'http://github.com/cli/cli.git/'; Expected = 'cli/cli'; Message = 'with .git and a slash' }
    @{
        Value = 'https://github.com/cli/cli//'
        Expected = 'cli/cli'
        Message = 'or with two slashes, as gh trims them all'
    }
    @{ Value = 'https://github.com/cli/cli?tab=readme'; Expected = 'cli/cli'; Message = 'and with a query' }
    @{ Value = 'https://github.com/cli/cli#readme'; Expected = 'cli/cli'; Message = 'or a fragment' }
    @{
        Value = 'https://github.com/cli/cli/issues/1'
        Expected = 'cli/cli'
        Message = 'or an item''s own path, as Core reads a URL'
    }
    @{
        Value = 'https://user@github.com:443/cli/cli'
        Expected = 'cli/cli'
        Message = 'and a URL''s user and port are dropped, as gh drops them'
    }
    @{
        Value = 'ssh://git@github.com:22/cli/cli.git'
        Expected = 'cli/cli'
        Message = 'and an ssh:// URL with a user and a port'
    }
    @{ Value = 'git://github.com/cli/cli.git'; Expected = 'cli/cli'; Message = 'and a git:// URL' }
    @{ Value = 'git+ssh://git@github.com:22/cli/cli.git'; Expected = 'cli/cli'; Message = 'and a git+ssh:// URL' }
    @{ Value = 'git+https://user@github.com/cli/cli.git'; Expected = 'cli/cli'; Message = 'and a git+https:// URL' }
    @{ Value = 'git@github.com:cli/cli.git'; Expected = 'cli/cli'; Message = 'and the SSH form' }
    @{
        Value = 'git@github.com:8443:cli/cli'
        Expected = '8443:cli/cli'
        Message = 'whose owner runs from the first colon to the last slash, as gh reads it'
    }
    @{
        Value = [pscustomobject]@{ Url = 'https://github.com/cli/cli'; FullName = 'x/y' }
        Expected = 'cli/cli'
        Message = 'An object is read by its Url first, as Core reads it'
    }
    @{
        Value = [pscustomobject]@{ NameWithOwner = 'cli/cli' }
        Expected = 'cli/cli'
        Message = 'or by its NameWithOwner, as a search result''s Repository has it'
    }
    @{ Value = @{ full_name = 'cli/cli' }; Expected = 'cli/cli'; Message = 'and a hashtable by its keys' }
)

# Act / Assert
foreach ($row in $rows) {
    Assert-Equal -Expected $row.Expected -Actual (ConvertTo-SearchRepository -Repository $row.Value) `
        -Message $row.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories on another host, with GH_HOST not set
$rows = @(
    @{
        Value = 'ghe.example.com/o/r'
        Shown = 'ghe.example.com/o/r'
        Host = 'ghe.example.com'
        Message = 'HOST/OWNER/REPO on another host throws'
    }
    @{
        Value = 'https://ghe.example.com:8443/o/r.git'
        Shown = 'https://ghe.example.com:8443/o/r.git'
        Host = 'ghe.example.com'
        Message = 'and so does a URL there, compared without its port'
    }
    @{
        Value = 'git@ghe.example.com:o/r'
        Shown = 'git@ghe.example.com:o/r'
        Host = 'ghe.example.com'
        Message = 'and the SSH form'
    }
    @{
        Value = 'ghe.example.com:8443/o/r.git'
        Shown = 'ghe.example.com:8443/o/r'
        Host = 'ghe.example.com:8443'
        Message = 'and HOST:PORT/OWNER/REPO text, whose port stays in the host, as gh keeps it'
    }
    @{
        Value = 'github.com:443/o/r'
        Shown = 'github.com:443/o/r'
        Host = 'github.com:443'
        Message = 'github.com:443 included, which is not github.com to gh'
    }
    @{
        Value = [pscustomobject]@{ Url = 'https://ghe.example.com/o/r' }
        Shown = 'https://ghe.example.com/o/r'
        Host = 'ghe.example.com'
        Message = 'and an Enterprise repository object'
    }
)

# Act / Assert
foreach ($row in $rows) {
    $like = [WildcardPattern]::Escape("'$($row.Shown)' is on $($row.Host), but GH_HOST is not set, so it is compared with github.com: set GH_HOST to $($row.Host) to search there.")
    Assert-Throws -ScriptBlock {
        ConvertTo-SearchRepository -Repository $row.Value
    } -MessageLike $like -Message $row.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - GH_HOST names an Enterprise host, which gh then searches
$env:GH_HOST = 'GHE.example.com'
try {
    # Act / Assert
    Assert-Equal -Expected 'o/r' -Actual (ConvertTo-SearchRepository -Repository 'https://ghe.example.com/o/r') `
        -Message 'A repository on the host GH_HOST names is cut down to OWNER/REPO, whatever the case'
    Assert-Equal -Expected 'o/r' -Actual (ConvertTo-SearchRepository -Repository 'o/r') `
        -Message 'and OWNER/REPO is searched there'
    Assert-Throws -ScriptBlock {
        ConvertTo-SearchRepository -Repository 'https://github.com/o/r'
    } -MessageLike "'https://github.com/o/r' is on github.com, but GH_HOST names GHE.example.com: set GH_HOST to github.com to search there." `
        -Message 'A github.com repository is refused, not searched for on the Enterprise host'
    Assert-Throws -ScriptBlock {
        ConvertTo-SearchRepository -Repository 'ghe.example.com:8443/o/r'
    } -MessageLike "'ghe.example.com:8443/o/r' is on ghe.example.com:8443, but GH_HOST names GHE.example.com*" `
        -Message 'and so is the same host with a port in text, which gh reads as another host'
}
finally {
    $env:GH_HOST = $null
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - GH_HOST names a host with a port
$env:GH_HOST = 'ghe.example.com:8443'
try {
    # Act / Assert
    Assert-Equal -Expected 'o/r' -Actual (ConvertTo-SearchRepository -Repository 'ghe.example.com:8443/o/r') `
        -Message 'HOST:PORT/OWNER/REPO text matches a GH_HOST that names the same port'
}
finally {
    $env:GH_HOST = $null
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - GH_HOST naming a subdomain of github.com
$env:GH_HOST = 'gist.github.com'
try {
    # Act / Assert
    Assert-Equal -Expected 'o/r' -Actual (ConvertTo-SearchRepository -Repository 'www.github.com/o/r') `
        -Message 'A GH_HOST on a subdomain of github.com is github.com too'
}
finally {
    $env:GH_HOST = $null
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text that names no repository gh can read
$rows = @(
    @{ Value = 'cli'; Message = 'A bare name throws, as repo:cli matches nothing' }
    @{ Value = 'https://api.github.com/repos/o'; Message = 'and a REST URL, which is no repository''s web URL' }
    @{ Value = 'api.github.com/repos/o'; Message = 'and the same without a scheme' }
    @{ Value = 'https://ghe.example.com/api/v3/repos/o/r'; Message = 'and an Enterprise REST URL' }
    @{ Value = 'a/b/c/d'; Message = 'and a path with too many parts' }
    @{ Value = 'o//r'; Message = 'and an empty part' }
    @{ Value = 'HTTPS://github.com/o/r'; Message = 'and a scheme in capitals, which gh does not read as one' }
    @{ Value = 'ftp://github.com/o/r'; Message = 'and a scheme gh does not know' }
    @{ Value = 'https:github.com/o/r'; Message = 'and a scheme without its slashes' }
    @{ Value = 'github.com:o/r'; Message = 'and HOST:OWNER/REPO with no user' }
)

# Act / Assert
foreach ($row in $rows) {
    $like = [WildcardPattern]::Escape("'$($row.Value)' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL.")
    Assert-Throws -ScriptBlock {
        ConvertTo-SearchRepository -Repository $row.Value
    } -MessageLike $like -Message $row.Message
}

# Without its colon, or with a port, the user reads as a token before a host and a path, so it is hidden.
$withPort = [WildcardPattern]::Escape(
    "'***@github.com:8443/o/r' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL.")
$withoutColon = [WildcardPattern]::Escape(
    "'***@github.com/o/r' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL.")
Assert-Throws -ScriptBlock {
    ConvertTo-SearchRepository -Repository 'git@github.com:8443/o/r'
} -MessageLike $withPort `
    -Message 'The SSH form with a port, where gh reads no repository, is refused with the user hidden'
Assert-Throws -ScriptBlock {
    ConvertTo-SearchRepository -Repository 'git@github.com/o/r'
} -MessageLike $withoutColon -Message 'and so is the SSH form without its colon'
Assert-Throws -ScriptBlock {
    ConvertTo-SearchRepository -Repository 'org-123@github.com:o/r.git'
} -MessageLike "'org-123@github.com:o/r.git' is not a repository*" `
    -Message 'The SSH form with a user other than git is refused, as gh cannot read it'
Assert-Throws -ScriptBlock {
    ConvertTo-SearchRepository -Repository 'GIT@github.com:o/r'
} -MessageLike "'GIT@github.com:o/r' is not a repository*" -Message 'and GIT@ in capitals, as gh matches git@ with case'
#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - what Core refuses before the form is read
Assert-Throws -ScriptBlock {
    ConvertTo-SearchRepository -Repository '-x/y'
} -MessageLike "'-x/y' is not a repository*" -Message 'A leading dash throws, so gh never reads it as an option'
Assert-Throws -ScriptBlock {
    ConvertTo-SearchRepository -Repository ([pscustomobject]@{ Url = 'https://api.github.com/repos/o/r' })
} -MessageLike 'A repository object needs a repository''s web URL*' `
    -Message 'An object with only a REST url throws Core''s message'

exit (Complete-TestRun)
