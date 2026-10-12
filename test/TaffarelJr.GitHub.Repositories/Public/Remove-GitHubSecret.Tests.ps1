#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubSecret -Name 'OLD' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'delete', '--repo', 'o/r', '--', 'OLD') -Actual $call.Arguments `
        -Message 'The name and repository are passed to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one scope at a time, each with what goes with it
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubSecret -Name 'OLD' -Environment 'prod' -Repository 'o/r'
    Remove-GitHubSecret -Name 'OLD' -Organization 'org' -Application 'Codespaces'
    Remove-GitHubSecret -Name 'OLD' -User -Application codespaces
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('secret', 'delete', '--env=prod', '--repo', 'o/r', '--', 'OLD') `
        -Actual $calls[0].Arguments `
        -Message 'An environment''s secret is deleted with --env, in its repository'
    Assert-Equal -Expected @('secret', 'delete', '--org=org', '--app', 'codespaces', '--', 'OLD') `
        -Actual $calls[1].Arguments `
        -Message 'An organization''s with --org, the application lower-cased'
    Assert-Equal -Expected @('secret', 'delete', '--user', '--app', 'codespaces', '--', 'OLD') `
        -Actual $calls[2].Arguments `
        -Message 'The user''s with --user'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names from piped objects, and an environment that starts with a dash
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ Name = 'A' }, [PSCustomObject]@{ Name = 'B' }) | Remove-GitHubSecret -Repository 'o/r'
    Remove-GitHubSecret -Name 'OLD' -Environment '-x'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 3 -Actual $calls.Count -Message 'Each piped object is deleted by its Name in its own call'
    Assert-Equal -Expected @('secret', 'delete', '--repo', 'o/r', '--', 'B') -Actual $calls[1].Arguments `
        -Message 'The second piped name is deleted too'
    Assert-Equal -Expected @('secret', 'delete', '--env=-x', '--', 'OLD') -Actual $calls[2].Arguments `
        -Message 'The environment travels joined to its flag, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - secrets listed from every scope, as Get-GitHubSecret returns them
$listing = New-FakeGitHubCli -Output @('[{"name":"TOKEN","visibility":"all"}]')
try {
    $listed = @(
        Get-GitHubSecret -Organization 'org'
        Get-GitHubSecret -Environment 'prod' -Repository 'other/repo'
        Get-GitHubSecret -User
        Get-GitHubSecret -Repository 'ghe.example.com/o/r' -Application dependabot
        Get-GitHubSecret
    )
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli
try {
    # Act
    $listed | Remove-GitHubSecret
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 5 -Actual $calls.Count -Message 'Each piped secret is deleted in its own call'
    Assert-Equal -Expected @('secret', 'delete', '--org=org', '--app', 'actions', '--', 'TOKEN') `
        -Actual $calls[0].Arguments `
        -Message 'An organization''s secret is deleted from the organization, not the current repository'
    Assert-Equal -Expected @('secret', 'delete', '--env=prod', '--repo', 'other/repo', '--', 'TOKEN') `
        -Actual $calls[1].Arguments `
        -Message 'An environment''s from that environment of its own repository'
    Assert-Equal -Expected @('secret', 'delete', '--user', '--app', 'codespaces', '--', 'TOKEN') `
        -Actual $calls[2].Arguments `
        -Message 'The user''s from the user'
    Assert-Equal `
        -Expected @('secret', 'delete', '--app', 'dependabot', '--repo', 'ghe.example.com/o/r', '--', 'TOKEN') `
        -Actual $calls[3].Arguments `
        -Message 'A repository''s from its repository and application, host included'
    Assert-Equal -Expected @('secret', 'delete', '--app', 'actions', '--', 'TOKEN') -Actual $calls[4].Arguments `
        -Message 'and one listed from the current directory''s repository from the current one again, the scope of one secret not leaking into the next'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listed secrets piped with a scope that names where they live: an environment's with its own repository, an enterprise one with OWNER/REPO, an environment's with its own environment, and the user's with -User
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod' } | Remove-GitHubSecret -Repository 'o/r'
    [PSCustomObject]@{ Name = 'A'; Repository = 'ghe.io/o/r'; Application = 'actions' } | Remove-GitHubSecret `
        -Repository 'o/r'
    [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod' } | Remove-GitHubSecret -Environment 'prod'
    [PSCustomObject]@{ Name = 'U'; User = $true; Application = 'actions' } | Remove-GitHubSecret -User
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('secret', 'delete', '--env=prod', '--repo', 'o/r', '--', 'B') -Actual $calls[0].Arguments `
        -Message 'An environment''s secret piped with its own repository keeps its environment, so the repository''s namesake is not deleted'
    Assert-Equal -Expected @('secret', 'delete', '--app', 'actions', '--repo', 'ghe.io/o/r', '--', 'A') `
        -Actual $calls[1].Arguments `
        -Message 'An enterprise secret piped with OWNER/REPO is deleted on its own host'
    Assert-Equal -Expected @('secret', 'delete', '--env=prod', '--repo', 'o/r', '--', 'B') -Actual $calls[2].Arguments `
        -Message 'and one piped with its own environment from that environment of its repository'
    Assert-Equal -Expected @('secret', 'delete', '--user', '--', 'U') -Actual $calls[3].Arguments `
        -Message 'A piped actions Application is dropped beside -User, whose secrets are always Codespaces'''
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listed secret piped in with -Repository naming its own repository, in another case
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Name = 'TOKEN'; Repository = 'a/b'; Application = 'actions' } | Remove-GitHubSecret `
        -Repository 'A/B'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'delete', '--app', 'actions', '--repo', 'A/B', '--', 'TOKEN') `
        -Actual $call.Arguments `
        -Message 'A -Repository that names the piped secret''s own repository is used'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a piped object that names no place, with a repository named
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Name = 'TOKEN'; Application = 'actions' } | Remove-GitHubSecret -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'delete', '--app', 'actions', '--repo', 'o/r', '--', 'TOKEN') `
        -Actual $call.Arguments `
        -Message 'A repository named as a parameter is used for a piped object that names no place'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - scopes gh refuses together, a piped secret of another repository, an application for an environment, bad names, piped text, and a repository given as $null
$appAndEnvironment = '-Application and -Environment cannot be used together: an environment''s secrets are always Actions'', and a piped secret''s Application or Environment counts too. Give only one.'
$place = 'a secret lives in one place - a repository, one of its environments, an organization, or the user. Give only one.'
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name 'OLD' -Environment 'prod' -Organization 'org' -User
    } -MessageLike "-Environment and -Organization cannot be used together: $place" `
        -Message 'An environment, an organization, and the user together are refused, saying why'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'OLD'; Environment = 'prod'; Organization = 'org' } | Remove-GitHubSecret
    } -MessageLike "-Environment and -Organization cannot be used together: $place" `
        -Message 'as is a piped object claiming two scopes'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'S'; Repository = 'a/b' } | Remove-GitHubSecret -Repository 'c/d'
    } -MessageLike 'Secret S is in a/b, but -Repository names c/d: give one or the other.' `
        -Message 'A piped secret from another repository than -Repository names is refused, so its namesake there is not deleted'
    $savedHost = $env:GH_HOST
    $env:GH_HOST = $null
    try {
        Assert-Throws -ScriptBlock {
            [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' } | Remove-GitHubSecret `
                -Repository 'ghe.io/o/r'
        } -MessageLike 'Secret A is in github.com/o/r, but -Repository names ghe.io/o/r: give one or the other.' `
            -Message 'A secret listed without a host lives on the default host, so another host is refused'
    }
    finally {
        $env:GH_HOST = $savedHost
    }

    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' } | Remove-GitHubSecret `
            -Application 'dependabot'
    } -MessageLike 'Secret A is in the actions store, but -Application names dependabot: give one or the other.' `
        -Message 'An application other than the piped secret''s is refused, so its Dependabot namesake is not deleted'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod' } | Remove-GitHubSecret `
            -Repository 'x/y'
    } -MessageLike 'Secret B is in o/r, but -Repository names x/y: give one or the other.' `
        -Message 'as is an environment''s secret piped with another repository'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'F'; Repository = $null; Application = 'actions' } | Remove-GitHubSecret `
            -Repository 'x/y'
    } -MessageLike "Secret F was listed from the current directory's repository, but -Repository names x/y: leave -Repository off, or list the secret with -Repository." `
        -Message 'and a secret listed from the current directory''s repository, which may not be x/y'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'C'; Organization = 'org'; Application = 'actions' } | Remove-GitHubSecret `
            -Repository 'o/r'
    } -MessageLike "-Repository and the piped secret's organization cannot be used together: *" `
        -Message 'and an organization''s secret piped with a repository, which would delete the repository''s namesake'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'C'; Organization = 'org'; Application = 'actions' } | Remove-GitHubSecret `
            -Organization 'other'
    } -MessageLike 'Secret C is in organization org, but -Organization names other: give one or the other.' `
        -Message 'and one piped with another organization than its own, so its namesake there is not deleted'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'R'; Repository = 'o/r'; Application = 'actions' } | Remove-GitHubSecret `
            -Environment 'prod'
    } -MessageLike "-Environment and the piped secret's repository cannot be used together: *" `
        -Message 'and a repository''s own secret piped with an environment'
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name '--user'
    } -MessageLike "*'--user' is not a secret name: give letters, digits, and _, not led by a digit or GITHUB_." `
        -Message 'A name that is no secret name is refused, as Set-GitHubSecret refuses it'
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name ''
    } -MessageLike "*'' is not a secret name*" -Message 'as is an empty one'
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name 'OLD' -Environment ' '
    } -MessageLike "*-Environment is blank: give the environment's name, or leave it out." `
        -Message 'and a blank environment'
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name 'OLD' -Organization 'org/x'
    } -MessageLike "*'org/x' is not an organization name: give letters, digits, and dashes." `
        -Message 'and an organization name that is not one'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'TOKEN'; Repository = 'o/r'; Environment = 'prod' } | Remove-GitHubSecret `
            -Application actions
    } -MessageLike $appAndEnvironment `
        -Message 'A piped environment''s secret with -Application is refused, not deleted from the repository instead'
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name 'OLD' -Environment 'prod' -Application actions
    } -MessageLike '-Application and -Environment cannot be used together: an environment''s secrets are always Actions''. Give only one.' `
        -Message 'as is -Application beside -Environment, with nothing about a pipe when nothing was piped'
    Assert-Throws -ScriptBlock {
        'OLD' | Remove-GitHubSecret
    } -MessageLike '*input object cannot be bound*' -Message 'A piped string is refused rather than taken as a name'
    Assert-Throws -ScriptBlock {
        @{ Name = 'OLD'; Organization = 'org' } | Remove-GitHubSecret
    } -MessageLike '*input object cannot be bound*' `
        -Message 'as is a piped hashtable, rather than deleting a secret named by its text'
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name 'OLD' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of deleting from the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside each scope, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(
        Remove-GitHubSecret -Name 'OLD' -Environment 'prod' -Repository 'o/r' -WhatIf
        Remove-GitHubSecret -Name 'OLD' -Organization 'org' -Application 'dependabot' -WhatIf
        Remove-GitHubSecret -Name 'OLD' -User -Application 'codespaces' -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no secret is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Remove-GitHubSecret -Name 'OLD' -Organization 'org' -Application 'dependabot' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'delete', '--org=org', '--app', 'dependabot', '--', 'OLD') `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false delete as before, neither one reaching gh nor counting as a scope'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two listed secrets piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $secrets = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org'; Application = 'actions' }
    )
    $out = @($secrets | Remove-GitHubSecret -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped secret is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a scope that names another place than the piped secret's
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'S'; Repository = 'a/b' } | Remove-GitHubSecret -Repository 'c/d' -WhatIf
    } -MessageLike 'Secret S is in a/b, but -Repository names c/d: give one or the other.' `
        -Message '-WhatIf still refuses a secret listed from another repository than -Repository names'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' } | Remove-GitHubSecret `
            -Application 'dependabot' `
            -WhatIf
    } -MessageLike 'Secret A is in the actions store, but -Application names dependabot: give one or the other.' `
        -Message 'and another application than the piped secret''s'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'S'; Organization = 'org' } | Remove-GitHubSecret -Organization 'other' -WhatIf
    } -MessageLike 'Secret S is in organization org, but -Organization names other: give one or the other.' `
        -Message 'and one listed from another organization'
    Assert-Throws -ScriptBlock {
        Remove-GitHubSecret -Name 'OLD' -Environment 'prod' -Organization 'org' -WhatIf
    } -MessageLike '-Environment and -Organization cannot be used together:*' -Message 'and two scopes at once'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines beside each scope, with a credential in -Repository's URL
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubSecret -Name 'OLD' -Environment 'prod' -Repository 'https://user:SENTINEL@github.com/o/r' -WhatIf
        Remove-GitHubSecret -Name 'OLD' -Organization 'org' -Application 'dependabot' -WhatIf
        Remove-GitHubSecret -Name 'OLD' -User -Application 'codespaces' -WhatIf
        Remove-GitHubSecret -Name 'OLD' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete secret" on target "o/r environment prod secret OLD".'
        'What if: Performing the operation "Delete secret" on target "organization org dependabot secret OLD".'
        'What if: Performing the operation "Delete secret" on target "the current user codespaces secret OLD".'
        'What if: Performing the operation "Delete secret" on target "secret OLD".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names the secret in its scope and application, the repository without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two listed secrets piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $secrets = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'https://user:SENTINEL@github.com/o/r'; Application = 'actions' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org'; Application = 'actions' }
    )
    $result = Get-WhatIfOutput -ScriptBlock { $secrets | Remove-GitHubSecret -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete secret" on target "o/r actions secret A".'
        'What if: Performing the operation "Delete secret" on target "organization org actions secret B".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped secret gets its own line, where it was listed from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
