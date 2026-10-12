#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') `
    -Force `
    -PassThru

$convert = {
    param($Repository, $Hostname)

    ConvertTo-GitHubApiRepository -Repository $Repository -Hostname $Hostname
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a repository, and the path and host each gives
$forms = @(
    @{
        Given    = $null
        Hostname = ''
        Expected = [PSCustomObject]@{ Path = '{owner}/{repo}'; Hostname = $null }
        Message  = 'No repository is gh''s own placeholder for the current directory''s, on gh''s default host'
    }
    @{
        Given    = 'cli/cli'
        Hostname = ''
        Expected = [PSCustomObject]@{ Path = 'cli/cli'; Hostname = $null }
        Message  = 'OWNER/REPO goes into the path as it is'
    }
    @{
        Given    = 'ghe.example.com/o/r'
        Hostname = ''
        Expected = [PSCustomObject]@{ Path = 'o/r'; Hostname = 'ghe.example.com' }
        Message  = 'HOST/OWNER/REPO puts the host apart'
    }
    @{
        Given    = 'https://github.com/o/my.repo.git/'
        Hostname = ''
        Expected = [PSCustomObject]@{ Path = 'o/my.repo'; Hostname = 'github.com' }
        Message  = 'A URL loses its .git ending and trailing slash, and keeps a dot inside the name'
    }
    @{
        Given    = [PSCustomObject]@{ Url = 'https://ghe.example.com/o/r'; NameWithOwner = 'o/r' }
        Hostname = ''
        Expected = [PSCustomObject]@{ Path = 'o/r'; Hostname = 'ghe.example.com' }
        Message  = 'An object is read by its Url, so its host is kept'
    }
    @{
        Given    = $null
        Hostname = 'ghe.example.com'
        Expected = [PSCustomObject]@{ Path = '{owner}/{repo}'; Hostname = 'ghe.example.com' }
        Message  = '-Hostname alone asks that host about the current directory''s repository'
    }
    @{
        Given    = 'GHE.example.com/o/r'
        Hostname = 'ghe.example.com'
        Expected = [PSCustomObject]@{ Path = 'o/r'; Hostname = 'ghe.example.com' }
        Message  = 'and a host that agrees with it, in any case, is fine'
    }
)

# Act / Assert
foreach ($form in $forms) {
    $place = & $module $convert $form.Given $form.Hostname
    Assert-Equal -Expected $form.Expected -Actual $place -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values the API cannot be asked about, and why each is refused
$notApi = "is not a repository the API can be asked about: give OWNER/REPO, HOST/OWNER/REPO, or https://HOST/OWNER/REPO."
$refused = @(
    @{
        Given = 'o/r/../../orgs/x'
        Hostname = ''
        Pattern = "'o/r/../../orgs/x' $notApi"
        Message = 'A path that climbs to another endpoint is refused'
    }
    @{ Given = 'o/..'; Hostname = ''; Pattern = "'o/..' $notApi"; Message = 'as is a name of two dots' }
    @{ Given = '../r'; Hostname = ''; Pattern = "'../r' $notApi"; Message = 'and an owner of two dots' }
    @{
        Given = 'git@github.com:o/r.git'
        Hostname = ''
        Pattern = "'git@github.com:o/r.git' $notApi"
        Message = 'An SSH address is refused'
    }
    @{ Given = 'r'; Hostname = ''; Pattern = "'r' $notApi"; Message = 'and a bare name with no owner' }
    @{
        Given = 'ghe.example.com/o/r'
        Hostname = 'github.com'
        Pattern = "'ghe.example.com/o/r' is on ghe.example.com, but -Hostname names github.com: give one or the other."
        Message = 'A host that disagrees with -Hostname is refused'
    }
    @{
        Given = '--web'
        Hostname = ''
        Pattern = "*'--web' is not a repository*"
        Message = 'An option-like value is refused by Core''s resolver'
    }
    @{
        Given = [PSCustomObject]@{ Url = 'https://ghe.example.com:8443/o/r' }
        Hostname = ''
        Pattern = "'https://ghe.example.com:8443/o/r' names a port, which gh api cannot be given: give the host without one."
        Message = 'A host with a port is refused, as gh api''s --hostname cannot take one'
    }
    @{
        Given = 'ghe.example.com:8443/o/r'
        Hostname = ''
        Pattern = "'ghe.example.com:8443/o/r' names a port, which gh api cannot be given: give the host without one."
        Message = 'given as HOST:PORT/OWNER/REPO too'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module $convert $case.Given $case.Hostname
    } -MessageLike $case.Pattern -Message $case.Message
}

exit (Complete-TestRun)
