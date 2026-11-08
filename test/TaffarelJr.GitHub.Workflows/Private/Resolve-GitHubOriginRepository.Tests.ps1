#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') `
    -Force `
    -PassThru

$resolve = {
    param($Repository, $InputObject, $Url)
    Resolve-GitHubOriginRepository -Repository $Repository -InputObject $InputObject -Url $Url -Item 'Cache 5'
}
$runUrl = 'https://github.com/o/r/actions/runs/9'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every source of a repository, and the one each gives
$forms = @(
    @{ Repository = $null; InputObject = $null; Url = ''; Expected = $null; Message = 'Nothing known gives nothing' }
    @{ Repository = 'a/b'; InputObject = $null; Url = ''; Expected = 'a/b'; Message = '-Repository alone is used' }
    @{
        Repository  = [PSCustomObject]@{ NameWithOwner = 'a/b' }
        InputObject = $null
        Url         = ''
        Expected    = 'a/b'
        Message     = 'whether text or a repository object'
    }
    @{
        Repository  = $null
        InputObject = [PSCustomObject]@{ Id = 5; Repository = 'o/r' }
        Url         = ''
        Expected    = 'o/r'
        Message     = 'An object''s Repository is used when -Repository is not given'
    }
    @{
        Repository  = $null
        InputObject = @{ id = 5; repository = 'o/r' }
        Url         = ''
        Expected    = 'o/r'
        Message     = 'as is a hashtable''s, in any case'
    }
    @{
        Repository  = $null
        InputObject = $null
        Url         = $runUrl
        Expected    = 'https://github.com/o/r'
        Message     = 'A run''s Url gives its repository'
    }
    @{
        Repository  = $null
        InputObject = [PSCustomObject]@{ Id = 5; Repository = 'o/r' }
        Url         = 'https://github.com/x/y/actions/runs/1'
        Expected    = 'o/r'
        Message     = 'An object''s Repository comes before its Url'
    }
    @{ Repository = $null; InputObject = 'npm-abc'; Url = ''; Expected = $null; Message = 'A plain key has no origin' }
    @{
        Repository  = $null
        InputObject = $null
        Url         = 'https://github.com/o/r'
        Expected    = $null
        Message     = 'A Url that is not a run''s gives nothing'
    }
    @{
        Repository  = 'github.com/O/R'
        InputObject = $null
        Url         = $runUrl
        Expected    = 'github.com/O/R'
        Message     = 'The same repository written another way agrees, without case, and -Repository is used as given'
    }
    @{
        Repository  = 'https://github.com/o/r.git'
        InputObject = [PSCustomObject]@{ Repository = 'o/r' }
        Url         = ''
        Expected    = 'https://github.com/o/r.git'
        Message     = 'as does a clone URL'
    }
    @{
        Repository  = 'o/r'
        InputObject = $null
        Url         = 'https://ghe.example.com/o/r/actions/runs/9'
        Expected    = 'ghe.example.com/o/r'
        Message     = 'A -Repository without a host stays on the host of an Enterprise run'
    }
    @{
        Repository  = $null
        InputObject = [ordered]@{ Keys = 'k'; Repository = 'o/r' }
        Url         = ''
        Expected    = 'o/r'
        Message     = 'A dictionary holding a Keys entry is still read for its Repository'
    }
    @{
        Repository  = $null
        InputObject = @([PSCustomObject]@{ Id = 5; Repository = 'o/r' })
        Url         = ''
        Expected    = 'o/r'
        Message     = 'A collection of one object is read as that object'
    }
)

# Act / Assert
foreach ($form in $forms) {
    $reference = & $module $resolve $form.Repository $form.InputObject $form.Url
    Assert-Equal -Expected $form.Expected -Actual $reference -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -Repository that names another repository than the object's
$refused = @(
    @{
        Repository  = 'c/d'
        InputObject = [PSCustomObject]@{ Repository = 'o/r' }
        Url         = ''
        Origin      = 'o/r'
        Message     = 'Another owner and name'
    }
    @{
        Repository  = 'o/other'
        InputObject = $null
        Url         = $runUrl
        Origin      = 'o/r'
        Message     = 'another name'
    }
    @{
        Repository  = 'ghe.example.com/o/r'
        InputObject = $null
        Url         = $runUrl
        Origin      = 'github.com/o/r'
        Message     = 'or another host, when both give one, naming the host'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module $resolve $case.Repository $case.InputObject $case.Url
    } -MessageLike "Cache 5 is in $($case.Origin), but -Repository names $($case.Repository): give one or the other." `
        -Message "$($case.Message) throws"
}

exit (Complete-TestRun)
