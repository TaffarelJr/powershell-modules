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

$resolve = {
    param([hashtable]$Splat)

    Resolve-GitHubSecretScope @Splat
}

function New-Scope {
    param($Repository = $null, $Environment = $null, $Organization = $null, [bool]$User = $false, $Application = $null)

    [PSCustomObject]@{
        Repository   = $Repository
        Environment  = $Environment
        Organization = $Organization
        User         = $User
        Application  = $Application
    }
}

$environmentItem = [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod' }
$enterpriseItem = [PSCustomObject]@{ Name = 'A'; Repository = 'ghe.io/o/r'; Application = 'actions' }
$otherItem = [PSCustomObject]@{ Name = 'A'; Repository = 'a/b'; Environment = 'prod' }

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one row per combination of a command-line scope and a piped one, without -Strict (Set-, Get-)
$forms = @(
    @{
        Splat    = @{ CommandLine = @{}; Bound = @{ Organization = 'org'; Application = 'actions' }; Kind = 'secret' }
        Expected = New-Scope -Organization 'org' -Application 'actions'
        Message  = 'A piped scope alone is used'
    }
    @{
        Splat    = @{
            CommandLine = @{ Organization = 'org' }
            Bound = @{ Organization = 'org'; Repository = 'a/b'; Environment = 'prod' }
            Kind = 'secret'
        }
        Expected = New-Scope -Organization 'org'
        Message  = 'A command-line organization wins: the piped repository and environment are dropped'
    }
    @{
        Splat    = @{
            CommandLine = @{ Environment = 'prod' }
            Bound = @{ Environment = 'prod'; Repository = 'a/b'; Application = 'actions' }
            Kind = 'secret'
        }
        Expected = New-Scope -Repository 'a/b' -Environment 'prod'
        Message  = 'A command-line environment keeps the piped repository and drops a piped actions Application'
    }
    @{
        Splat    = @{
            CommandLine = @{ User = $true }
            Bound = @{ User = $true; Repository = 'a/b'; Application = 'actions' }
            Kind = 'secret'
        }
        Expected = New-Scope -User $true
        Message  = 'A command-line -User drops the piped repository and a piped actions Application'
    }
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'O/R' }
            Bound = @{ Repository = 'O/R'; Environment = 'prod' }
            Kind = 'secret'
            Piped = $environmentItem
            Item = 'Secret B'
        }
        Expected = New-Scope -Repository 'O/R' -Environment 'prod'
        Message  = 'A command-line -Repository naming the piped environment item''s own repository keeps its environment'
    }
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'x/y' }
            Bound = @{ Repository = 'x/y'; Environment = 'prod' }
            Kind = 'secret'
            Piped = $otherItem
            Item = 'Secret A'
        }
        Expected = New-Scope -Repository 'x/y'
        Message  = 'A command-line -Repository naming another repository wins, and the piped environment goes with the piped repository'
    }
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'o/r' }
            Bound = @{ Repository = 'o/r'; Application = 'actions' }
            Kind = 'secret'
            Piped = $enterpriseItem
            Item = 'Secret A'
        }
        Expected = New-Scope -Repository 'ghe.io/o/r' -Application 'actions'
        Message  = 'An enterprise item with an OWNER/REPO -Repository stays on its own host'
    }
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'o/r' }
            Bound = @{ Repository = 'o/r'; Organization = 'org' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Organization = 'org' }
            Item = 'Secret C'
        }
        Expected = New-Scope -Repository 'o/r'
        Message  = 'A command-line -Repository drops a piped organization'
    }
)

# Act / Assert
foreach ($form in $forms) {
    $scope = & $module $resolve $form.Splat
    Assert-Equal -Expected $form.Expected -Actual $scope -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same with -Strict (the removers), where a piped item names where it lives
$strictForms = @(
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'o/r' }
            Bound = @{ Repository = 'o/r'; Environment = 'prod' }
            Kind = 'secret'
            Piped = $environmentItem
            Strict = $true
            Item = 'Secret B'
        }
        Expected = New-Scope -Repository 'o/r' -Environment 'prod'
        Message  = 'Strict: the same -Repository keeps the piped environment'
    }
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'o/r' }
            Bound = @{ Repository = 'o/r'; Application = 'actions' }
            Kind = 'secret'
            Piped = $enterpriseItem
            Strict = $true
            Item = 'Secret A'
        }
        Expected = New-Scope -Repository 'ghe.io/o/r' -Application 'actions'
        Message  = 'Strict: an enterprise item with an OWNER/REPO -Repository is deleted on its own host'
    }
    @{
        Splat    = @{
            CommandLine = @{ Environment = 'PROD' }
            Bound = @{ Environment = 'PROD'; Repository = 'o/r' }
            Kind = 'variable'
            Piped = $environmentItem
            Strict = $true
            Item = 'Variable B'
        }
        Expected = New-Scope -Repository 'o/r' -Environment 'PROD'
        Message  = 'Strict: the piped item''s own environment, in any case, is fine'
    }
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'github.com/o/r' }
            Bound = @{ Repository = 'github.com/o/r'; Application = 'actions' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
            Strict = $true
            Item = 'Secret A'
        }
        Expected = New-Scope -Repository 'github.com/o/r' -Application 'actions'
        Message  = 'Strict: github.com/o/r names the default host an item listed as o/r lives on, with GH_HOST unset'
    }
    @{
        Splat    = @{
            CommandLine = @{ Application = 'Actions' }
            Bound = @{ Application = 'Actions'; Repository = 'o/r' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
            Strict = $true
            Item = 'Secret A'
        }
        Expected = New-Scope -Repository 'o/r' -Application 'Actions'
        Message  = 'Strict: the piped item''s own application, in any case, is fine'
    }
    @{
        Splat    = @{
            CommandLine = @{ Repository = 'o/r' }
            Bound = @{ Repository = 'o/r' }
            Kind = 'variable'
            Piped = [PSCustomObject]@{ Name = 'V'; Repository = 'o/r'; User = $true }
            Strict = $true
            Item = 'Variable V'
        }
        Expected = New-Scope -Repository 'o/r'
        Message  = 'Strict: a variable has no user scope, so a piped User is not read for one'
    }
)

# Act / Assert
$savedHost = $env:GH_HOST
$env:GH_HOST = $null
try {
    foreach ($form in $strictForms) {
        $scope = & $module $resolve $form.Splat
        Assert-Equal -Expected $form.Expected -Actual $scope -Message $form.Message
    }
}
finally {
    $env:GH_HOST = $savedHost
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - combinations that name more than one place
$secretPlace = 'a secret lives in one place - a repository, one of its environments, an organization, or the user'
$variablePlace = 'a variable lives in one place - a repository, one of its environments, or an organization'
$refused = @(
    @{
        Splat   = @{ CommandLine = @{}; Bound = @{ Environment = 'prod'; Organization = 'org' }; Kind = 'secret' }
        Pattern = "-Environment and -Organization cannot be used together: $secretPlace. Give only one."
        Message = 'Two scopes are refused, saying why'
    }
    @{
        Splat   = @{ CommandLine = @{}; Bound = @{ Repository = 'o/r'; Organization = 'org' }; Kind = 'variable' }
        Pattern = "-Organization and -Repository cannot be used together: $variablePlace. Give only one."
        Message = 'as are an organization and a repository, in the variable wording'
    }
    @{
        Splat   = @{
            CommandLine = @{ Environment = 'prod'; Application = 'agents' }
            Bound = @{ Environment = 'prod'; Application = 'agents' }
            Kind = 'secret'
        }
        Pattern = '-Application and -Environment cannot be used together: an environment''s secrets are always Actions''. Give only one.'
        Message = 'An application beside an environment, both on the command line, says nothing about a pipe'
    }
    @{
        Splat   = @{ CommandLine = @{}; Bound = @{ Environment = 'prod'; Application = 'dependabot' }; Kind = 'secret' }
        Pattern = '-Application and -Environment cannot be used together: an environment''s secrets are always Actions'', and a piped secret''s Application or Environment counts too. Give only one.'
        Message = 'while one that came through the pipe says the piped values count'
    }
    @{
        Splat   = @{
            CommandLine = @{ Repository = 'x/y' }
            Bound = @{ Repository = 'x/y'; Environment = 'prod' }
            Kind = 'secret'
            Piped = $otherItem
            Strict = $true
            Item = 'Secret A'
        }
        Pattern = 'Secret A is in a/b, but -Repository names x/y: give one or the other.'
        Message = 'Strict: a -Repository naming another repository than the piped item''s is refused'
    }
    @{
        Splat   = @{
            CommandLine = @{ Repository = 'x/y' }
            Bound = @{ Repository = 'x/y' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'F'; Repository = $null }
            Strict = $true
            Item = 'Secret F'
        }
        Pattern = "Secret F was listed from the current directory's repository, but -Repository names x/y: leave -Repository off, or list the secret with -Repository."
        Message = 'Strict: a -Repository beside an item listed from the current directory''s repository is refused'
    }
    @{
        Splat   = @{
            CommandLine = @{ Repository = 'o/r' }
            Bound = @{ Repository = 'o/r' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'C'; Organization = 'org' }
            Strict = $true
            Item = 'Secret C'
        }
        Pattern = "-Repository and the piped secret's organization cannot be used together: $secretPlace, and a secret is deleted where it was listed. Give only one."
        Message = 'Strict: a -Repository beside a piped organization item is refused'
    }
    @{
        Splat   = @{
            CommandLine = @{ Environment = 'prod' }
            Bound = @{ Environment = 'prod'; Repository = 'o/r' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'R'; Repository = 'o/r' }
            Strict = $true
            Item = 'Secret R'
        }
        Pattern = "-Environment and the piped secret's repository cannot be used together:*"
        Message = 'Strict: an -Environment beside a repository-level item is refused'
    }
    @{
        Splat   = @{
            CommandLine = @{ Environment = 'staging' }
            Bound = @{ Environment = 'staging'; Repository = 'o/r' }
            Kind = 'variable'
            Piped = $environmentItem
            Strict = $true
            Item = 'Variable B'
        }
        Pattern = 'Variable B is in environment prod, but -Environment names staging: give one or the other.'
        Message = 'Strict: another environment than the piped item''s is refused, naming both'
    }
    @{
        Splat   = @{
            CommandLine = @{ Organization = 'other' }
            Bound = @{ Organization = 'other' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'C'; Organization = 'org' }
            Strict = $true
            Item = 'Secret C'
        }
        Pattern = 'Secret C is in organization org, but -Organization names other: give one or the other.'
        Message = 'Strict: another organization than the piped item''s is refused, naming both'
    }
    @{
        Splat   = @{
            CommandLine = @{ User = $true }
            Bound = @{ User = $true }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'C'; Organization = 'org' }
            Strict = $true
            Item = 'Secret C'
        }
        Pattern = "-User and the piped secret's organization cannot be used together:*"
        Message = 'Strict: -User beside a piped organization item is refused'
    }
    @{
        Splat   = @{
            CommandLine = @{ Application = 'dependabot' }
            Bound = @{ Application = 'dependabot'; Repository = 'o/r' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
            Strict = $true
            Item = 'Secret A'
        }
        Pattern = 'Secret A is in the actions store, but -Application names dependabot: give one or the other.'
        Message = 'Strict: an -Application other than the piped item''s is refused, so its namesake in that store is not deleted'
    }
    @{
        Splat   = @{
            CommandLine = @{ Repository = 'ghe.io/o/r' }
            Bound = @{ Repository = 'ghe.io/o/r'; Application = 'actions' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
            Strict = $true
            Item = 'Secret A'
        }
        Pattern = 'Secret A is in github.com/o/r, but -Repository names ghe.io/o/r: give one or the other.'
        Message = 'Strict: an item listed without a host lives on the default host, so another host on the command line is refused'
    }
    @{
        Splat   = @{
            CommandLine = @{ User = $true; Application = 'dependabot' }
            Bound = @{ User = $true; Application = 'dependabot' }
            Kind = 'secret'
        }
        Pattern = '-Application and -User cannot be used together: the user''s secrets are always Codespaces''. Give only one.'
        Message = 'A non-Codespaces application beside the user is refused here, not by gh'
    }
    @{
        Splat   = @{
            CommandLine = @{ User = $true }
            Bound = @{ User = $true; Repository = 'o/r'; Application = 'dependabot' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'dependabot' }
            Item = 'Secret A'
        }
        Pattern = '-Application and -User cannot be used together: the user''s secrets are always Codespaces'', and a piped secret''s Application or User counts too. Give only one.'
        Message = 'as is a piped Dependabot secret beside -User, saying the piped value counts'
    }
    @{
        Splat   = @{
            CommandLine = @{ Environment = 'prod' }
            Bound = @{ Environment = 'prod'; User = $true; Application = 'codespaces' }
            Kind = 'secret'
            Piped = [PSCustomObject]@{ Name = 'A'; User = $true; Application = 'codespaces' }
            Item = 'Secret A'
        }
        Pattern = 'Secret A is for codespaces, and environments hold only Actions secrets: leave -Environment off, or list an Actions secret.'
        Message = 'A piped Codespaces secret beside -Environment says what to do'
    }
)

# Act / Assert
$savedHost = $env:GH_HOST
$env:GH_HOST = $null
try {
    foreach ($case in $refused) {
        Assert-Throws -ScriptBlock {
            & $module $resolve $case.Splat
        } -MessageLike $case.Pattern -Message $case.Message
    }
}
finally {
    $env:GH_HOST = $savedHost
}

exit (Complete-TestRun)
