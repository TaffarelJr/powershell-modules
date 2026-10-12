#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each form an issue reaches gh in
$cases = @(
    @{
        Reference  = '12'
        Repository = 'o/r'
        Expected   = 'o/r issue #12'
        Message    = 'A number is in -Repository'
    }
    @{
        Reference  = '12'
        Repository = ''
        Expected   = 'issue #12'
        Message    = 'and with none, in the current directory''s repository, left unnamed'
    }
    @{
        Reference  = 'https://github.com/o/r/issues/12#issuecomment-1'
        Repository = ''
        Expected   = 'o/r issue #12'
        Message    = 'A github.com URL names its own repository, without the host'
    }
    @{
        Reference  = 'https://ghe.example.com/o/r/issues/12'
        Repository = 'ghe.example.com/o/r'
        Expected   = 'ghe.example.com/o/r issue #12'
        Message    = 'and an Enterprise URL with its host'
    }
    @{
        Reference  = '12'
        Repository = 'https://github.com/o/r'
        Expected   = 'o/r issue #12'
        Message    = 'A -Repository URL reads as OWNER/REPO, as an issue URL does'
    }
    @{
        Reference  = 'https://www.github.com/o/r/issues/4'
        Repository = ''
        Expected   = 'o/r issue #4'
        Message    = 'and www.github.com is github.com'
    }
    @{
        Reference  = '12'
        Repository = 'https://user:SENTINEL@github.com/o/r'
        Expected   = 'o/r issue #12'
        Message    = 'A credential in -Repository is left out'
    }
    @{
        Reference  = 'https://user:SENTINEL@ghe.example.com/o/r/issues/12'
        Repository = ''
        Expected   = 'ghe.example.com/o/r issue #12'
        Message    = 'and so is one in an issue URL'
    }
)
foreach ($case in $cases) {
    $reference = $case.Reference
    $repository = $case.Repository

    # Act / Assert
    $target = & $module { Format-GitHubIssueTarget -Reference $args[0] -Repository $args[1] } $reference $repository
    Assert-Equal -Expected $case.Expected -Actual $target -Message $case.Message
}

exit (Complete-TestRun)
