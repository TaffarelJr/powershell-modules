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

$read = {
    param($Reference, [bool]$Named)

    Get-GitHubReferenceHost -Reference $Reference -Named:$Named
}

$savedHost = $env:GH_HOST
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - every form that names a host, and OWNER/REPO, with GH_HOST unset
    $env:GH_HOST = $null
    $forms = @(
        @{ Reference = 'https://GHE.io/o/r'; Expected = 'ghe.io'; Message = 'A URL names its host, lower-cased' }
        @{ Reference = 'ssh://git@ghe.io/o/r.git'; Expected = 'ghe.io'; Message = 'as does an ssh:// URL' }
        @{ Reference = 'git@ghe.io:o/r.git'; Expected = 'ghe.io'; Message = 'and the SSH form USER@HOST:OWNER/REPO' }
        @{ Reference = 'ghe.io/o/r'; Expected = 'ghe.io'; Message = 'and HOST/OWNER/REPO' }
        @{ Reference = 'api.github.com/o/r'; Expected = 'github.com'; Message = 'A *.github.com host is github.com' }
        @{
            Reference = 'o/r'
            Expected = 'github.com'
            Message = 'OWNER/REPO is on the default host: github.com with GH_HOST unset'
        }
        @{
            Reference = 'SENTINEL@ghe.io/o/r'
            Expected = 'ghe.io'
            Message = 'A token in front of the host is not part of it'
        }
        @{
            Reference = 'https://user:SENTINEL@GHE.io/o/r'
            Expected = 'ghe.io'
            Message = 'nor is a URL''s user and password'
        }
        @{
            Reference = 'https://user:pass@word@ghe.io/o/r'
            Expected = 'ghe.io'
            Message = 'nor is a password holding an @'
        }
        @{
            Reference = 'https://me@example.com:SENTINEL@ghe.io/o/r'
            Expected = 'ghe.io'
            Message = 'nor is a user name holding an @'
        }
        @{
            Reference = 'user:SENTINEL@ghe.io/o/r'
            Expected = 'github.com'
            Message = 'A user and password with no scheme name no host, so the default one is used'
        }
    )

    # Act / Assert
    foreach ($form in $forms) {
        Assert-Equal -Expected $form.Expected -Actual (& $module $read $form.Reference $false) -Message $form.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act - OWNER/REPO with GH_HOST set, and with -Named
    $env:GH_HOST = ' GHE.io '
    $fromEnvironment = & $module $read 'o/r' $false
    $named = @(& $module $read 'o/r' $true)

    # Assert
    Assert-Equal -Expected 'ghe.io' -Actual $fromEnvironment `
        -Message 'With GH_HOST set, OWNER/REPO is on the host it names'
    Assert-Equal -Expected 0 -Actual $named.Count `
        -Message 'and -Named returns nothing for a reference that names no host'
}
finally {
    $env:GH_HOST = $savedHost
}

exit (Complete-TestRun)
