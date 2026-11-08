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
    Remove-GitHubVariable -Name 'OLD' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'delete', '--repo', 'o/r', '--', 'OLD') -Actual $call.Arguments `
        -Message 'The name and repository are passed to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an environment's variable, and an organization's
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubVariable -Name 'OLD' -Environment 'prod' -Repository 'o/r'
    Remove-GitHubVariable -Name 'OLD' -Organization 'org'
    Remove-GitHubVariable -Name 'OLD' -Environment '-x'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('variable', 'delete', '--env=prod', '--repo', 'o/r', '--', 'OLD') `
        -Actual $calls[0].Arguments `
        -Message 'An environment''s variable is deleted with --env, in its repository'
    Assert-Equal -Expected @('variable', 'delete', '--org=org', '--', 'OLD') -Actual $calls[1].Arguments `
        -Message 'An organization''s with --org'
    Assert-Equal -Expected @('variable', 'delete', '--env=-x', '--', 'OLD') -Actual $calls[2].Arguments `
        -Message 'The environment travels joined to its flag, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names from piped objects
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ Name = 'A' }, [PSCustomObject]@{ Name = 'B' }) | Remove-GitHubVariable
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped object is deleted by its Name in its own call'
    Assert-Equal -Expected @('variable', 'delete', '--', 'B') -Actual $calls[1].Arguments `
        -Message 'The second piped name is deleted too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - variables read from every scope, as Get-GitHubVariable returns them
$listing = New-FakeGitHubCli -Output @('[{"name":"V","value":"1"}]')
try {
    $listed = @(
        Get-GitHubVariable -Organization 'org'
        Get-GitHubVariable -Environment 'prod' -Repository 'other/repo'
        Get-GitHubVariable -Repository 'o/r'
        Get-GitHubVariable
    )
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli
try {
    # Act
    $listed | Remove-GitHubVariable
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 4 -Actual $calls.Count -Message 'Each piped variable is deleted in its own call'
    Assert-Equal -Expected @('variable', 'delete', '--org=org', '--', 'V') -Actual $calls[0].Arguments `
        -Message 'An organization''s variable is deleted from the organization, not the current repository'
    Assert-Equal -Expected @('variable', 'delete', '--env=prod', '--repo', 'other/repo', '--', 'V') `
        -Actual $calls[1].Arguments `
        -Message 'An environment''s from that environment of its own repository'
    Assert-Equal -Expected @('variable', 'delete', '--repo', 'o/r', '--', 'V') -Actual $calls[2].Arguments `
        -Message 'A repository''s from its repository'
    Assert-Equal -Expected @('variable', 'delete', '--', 'V') -Actual $calls[3].Arguments `
        -Message 'and one read from the current directory''s repository from the current one again'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an environment's variable piped with its own repository
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod' } | Remove-GitHubVariable -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'delete', '--env=prod', '--repo', 'o/r', '--', 'B') -Actual $call.Arguments `
        -Message 'It keeps its environment, so the repository''s namesake is not deleted'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - scopes gh refuses together, piped text, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubVariable -Name 'OLD' -Environment 'prod' -Organization 'org'
    } -MessageLike '-Environment and -Organization cannot be used together: a variable lives in one place - a repository, one of its environments, or an organization. Give only one.' `
        -Message 'An environment and an organization together are refused, saying why'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'V'; Repository = 'a/b' } | Remove-GitHubVariable -Repository 'c/d'
    } -MessageLike 'Variable V is in a/b, but -Repository names c/d: give one or the other.' `
        -Message 'A piped variable from another repository than -Repository names is refused, so its namesake there is not deleted'
    $savedHost = $env:GH_HOST
    $env:GH_HOST = 'ghe.io'
    try {
        Assert-Throws -ScriptBlock {
            [PSCustomObject]@{ Name = 'V'; Repository = 'o/r' } | Remove-GitHubVariable -Repository 'github.com/o/r'
        } -MessageLike 'Variable V is in ghe.io/o/r, but -Repository names github.com/o/r: give one or the other.' `
            -Message 'With GH_HOST set, a variable listed without a host lives there, so github.com is another host'
    }
    finally {
        $env:GH_HOST = $savedHost
    }
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'F'; Repository = $null } | Remove-GitHubVariable -Repository 'x/y'
    } -MessageLike "Variable F was listed from the current directory's repository, but -Repository names x/y: leave -Repository off, or list the variable with -Repository." `
        -Message 'as is one read from the current directory''s repository'
    Assert-Throws -ScriptBlock {
        Remove-GitHubVariable -Name ' '
    } -MessageLike "*' ' is not a variable name*" -Message 'A blank name is refused, as Set-GitHubVariable refuses it'
    Assert-Throws -ScriptBlock {
        Remove-GitHubVariable -Name 'OLD' -Organization ''
    } -MessageLike "*'' is not an organization name: give letters, digits, and dashes." `
        -Message 'as is an empty organization'
    Assert-Throws -ScriptBlock {
        'OLD' | Remove-GitHubVariable
    } -MessageLike '*input object cannot be bound*' -Message 'A piped string is refused rather than taken as a name'
    Assert-Throws -ScriptBlock {
        @{ Name = 'OLD'; Organization = 'org' } | Remove-GitHubVariable
    } -MessageLike '*input object cannot be bound*' `
        -Message 'as is a piped hashtable, rather than deleting a variable named by its text'
    Assert-Throws -ScriptBlock {
        Remove-GitHubVariable -Name 'OLD' -Repository $null
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
        Remove-GitHubVariable -Name 'OLD' -Environment 'prod' -Repository 'o/r' -WhatIf
        Remove-GitHubVariable -Name 'OLD' -Organization 'org' -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no variable is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Remove-GitHubVariable -Name 'OLD' -Environment 'prod' -Repository 'o/r' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'delete', '--env=prod', '--repo', 'o/r', '--', 'OLD') -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false delete as before, neither one reaching gh nor counting as a scope'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two listed variables piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $variables = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org' }
    )
    $out = @($variables | Remove-GitHubVariable -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped variable is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a scope that names another place than the piped variable's
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'V'; Repository = 'a/b' } | Remove-GitHubVariable -Repository 'c/d' -WhatIf
    } -MessageLike 'Variable V is in a/b, but -Repository names c/d: give one or the other.' `
        -Message '-WhatIf still refuses a variable listed from another repository than -Repository names'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'V'; Organization = 'org' } | Remove-GitHubVariable -Organization 'other' -WhatIf
    } -MessageLike 'Variable V is in organization org, but -Organization names other: give one or the other.' `
        -Message 'and one listed from another organization'
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
        Remove-GitHubVariable -Name 'OLD' -Environment 'prod' -Repository 'https://user:SENTINEL@github.com/o/r' `
            -WhatIf
        Remove-GitHubVariable -Name 'OLD' -Organization 'org' -WhatIf
        Remove-GitHubVariable -Name 'OLD' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete variable" on target "o/r environment prod variable OLD".'
        'What if: Performing the operation "Delete variable" on target "organization org variable OLD".'
        'What if: Performing the operation "Delete variable" on target "variable OLD".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names the variable in its scope, the repository without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two listed variables piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $variables = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'https://user:SENTINEL@github.com/o/r' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org' }
    )
    $result = Get-WhatIfOutput -ScriptBlock { $variables | Remove-GitHubVariable -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete variable" on target "o/r variable A".'
        'What if: Performing the operation "Delete variable" on target "organization org variable B".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped variable gets its own line, where it was read from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
