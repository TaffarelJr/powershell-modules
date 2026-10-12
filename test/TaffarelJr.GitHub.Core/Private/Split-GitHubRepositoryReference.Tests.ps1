#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Reads a reference and joins what it found, or says it found nothing.
$read = {
    param([string]$Reference)
    $parts = Split-GitHubRepositoryReference -Reference $Reference
    if ($null -eq $parts) {
        return 'nothing'
    }

    "$($parts.Host)|$($parts.Owner)|$($parts.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every form, and what each gives
$forms = @(
    @{
        Reference = 'https://github.com/o/r'
        Expected = 'github.com|o|r'
        Message = 'A web URL gives its host, owner, and name'
    }
    @{
        Reference = 'http://ghe.example:8080/o/r.git/'
        Expected = 'ghe.example|o|r'
        Message = 'without a port, a .git, or a trailing slash'
    }
    @{
        Reference = 'https://github.com/o/r/issues/7?x=1#c'
        Expected = 'github.com|o|r'
        Message = 'and with an item''s own path after the repository'
    }
    @{
        Reference = 'ssh://git@github.com:22/o/r.git'
        Expected = 'github.com|o|r'
        Message = 'An ssh:// URL is read too'
    }
    @{ Reference = 'git@ghe.example:o/r.git'; Expected = 'ghe.example|o|r'; Message = 'and the SSH form' }
    @{ Reference = 'ghe.example/o/r'; Expected = 'ghe.example|o|r'; Message = 'HOST/OWNER/REPO gives its host' }
    @{
        Reference = 'ghe.example:8443/o/r.git'
        Expected = 'ghe.example:8443|o|r'
        Message = 'HOST:PORT/OWNER/REPO text keeps the port in its host, as gh does'
    }
    @{
        Reference = 'git+ssh://git@ghe.example/o/r.git'
        Expected = 'ghe.example|o|r'
        Message = 'A git+ssh:// URL is read, as gh reads it'
    }
    @{
        Reference = 'git+https://user@ghe.example:8443/o/r'
        Expected = 'ghe.example|o|r'
        Message = 'and a git+https:// URL, its port dropped like any URL''s'
    }
    @{
        Reference = 'GIT@ghe.example:o/r'
        Expected = 'nothing'
        Message = 'GIT@ is no URL to gh, which matches git@ with case'
    }
    @{ Reference = 'HTTPS://ghe.example/o/r'; Expected = 'nothing'; Message = 'and neither is HTTPS://' }
    @{
        Reference = 'git@ghe.example:8443/o/r'
        Expected = 'nothing'
        Message = 'The SSH form with a port and a slash gives nothing, as gh reads no repository there'
    }
    @{
        Reference = 'git@ghe.example:8443:o/r'
        Expected = 'ghe.example|8443:o|r'
        Message = 'while a second colon is part of the owner, as gh reads it'
    }
    @{ Reference = 'git@ghe.example/o/r'; Expected = 'nothing'; Message = 'and so does git@HOST/OWNER/REPO' }
    @{
        Reference = 'https://www.github.com/o/r'
        Expected = 'github.com|o|r'
        Message = 'www.github.com is github.com, as gh reads it'
    }
    @{ Reference = 'www.github.com/o/r'; Expected = 'github.com|o|r'; Message = 'in HOST/OWNER/REPO too' }
    @{
        Reference = 'https://gist.github.com/o/r'
        Expected = 'github.com|o|r'
        Message = 'and so is any other subdomain of github.com'
    }
    @{
        Reference = 'https://notgithub.com/o/r'
        Expected = 'notgithub.com|o|r'
        Message = 'while a host that only ends in github.com is not'
    }
    @{
        Reference = 'org-123@github.com:o/r.git'
        Expected = 'nothing'
        Message = 'An SSH form with another user than git gives nothing, as gh cannot read it'
    }
    @{
        Reference = 'https://api.github.com/repos/o/r'
        Expected = 'nothing'
        Message = 'A REST URL names no web page, so it gives nothing'
    }
    @{
        Reference = 'https://ghe.example/api/v3/repos/o/r'
        Expected = 'nothing'
        Message = 'and so does an Enterprise one'
    }
    @{
        Reference = 'https://user:pa@SENTINEL@ghe.example/o/r'
        Expected = 'ghe.example|o|r'
        Message = 'A password holding @ is part of the user information, never of the host'
    }
    @{
        Reference = 'ssh://git@x@ghe.example:22/o/r.git'
        Expected = 'ghe.example|o|r'
        Message = 'in any URL scheme, as gh reads it'
    }
    @{
        Reference = 'git@SENTINEL@ghe.example:o/r'
        Expected = 'ghe.example|o|r'
        Message = 'and so is the SSH form''s, which gh reads up to the last @ too'
    }
    @{ Reference = ' o/r.git '; Expected = '|o|r'; Message = 'OWNER/REPO gives no host' }
    @{ Reference = 'r'; Expected = 'nothing'; Message = 'A bare REPO gives nothing' }
    @{ Reference = 'a/b/c/d'; Expected = 'nothing'; Message = 'and so does a form with too many parts' }
    @{ Reference = ''; Expected = 'nothing'; Message = 'and an empty one' }
)

# Act / Assert
foreach ($form in $forms) {
    Assert-Equal -Expected $form.Expected -Actual (& $module $read $form.Reference) -Message $form.Message
}

exit (Complete-TestRun)
