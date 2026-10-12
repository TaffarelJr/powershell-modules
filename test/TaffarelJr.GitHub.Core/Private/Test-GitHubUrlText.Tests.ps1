#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Asks whether gh reads one reference as a URL.
$test = {
    param([string]$Text)
    Test-GitHubUrlText -Text $Text
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what gh reads as a URL, and what it reads as text
$cases = @(
    @{ Text = 'git@github.com:o/r'; Expected = $true; Message = 'git@ starts a URL' }
    @{ Text = 'https://github.com/o/r'; Expected = $true; Message = 'and so does https:' }
    @{ Text = 'http://h/o/r'; Expected = $true; Message = 'http:' }
    @{ Text = 'ssh://git@h/o/r'; Expected = $true; Message = 'ssh:' }
    @{ Text = 'git://h/o/r'; Expected = $true; Message = 'git:' }
    @{ Text = 'git+ssh://git@h/o/r'; Expected = $true; Message = 'git+ssh:' }
    @{ Text = 'git+https://h/o/r'; Expected = $true; Message = 'and git+https:' }
    @{ Text = 'GIT@github.com:o/r'; Expected = $false; Message = 'GIT@ is text: gh matches the prefixes with case' }
    @{ Text = 'HTTPS://github.com/o/r'; Expected = $false; Message = 'and so is HTTPS://' }
    @{ Text = 'user@github.com:o/r'; Expected = $false; Message = 'Another user is text' }
    @{ Text = 'ftp://h/o/r'; Expected = $false; Message = 'and so is a scheme gh does not know' }
    @{ Text = 'ghe.example.com:8443/o/r'; Expected = $false; Message = 'and HOST:PORT/OWNER/REPO' }
    @{ Text = ''; Expected = $false; Message = 'Nothing is no URL' }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual (& $module $test $case.Text) -Message $case.Message
}

exit (Complete-TestRun)
