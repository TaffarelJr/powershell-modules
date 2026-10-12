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
    Copy-GitHubLabel -Source 'TaffarelJr/.github' -Force -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'clone', 'TaffarelJr/.github', '--force', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message 'The source is positional, the destination goes through --repo, and -Force becomes --force'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - from a repository object into the current directory's repository
$fake = New-FakeGitHubCli
try {
    # Act
    Copy-GitHubLabel -Source ([PSCustomObject]@{ NameWithOwner = 'cli/cli'; Name = 'cli' })
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'clone', 'cli/cli') -Actual $call.Arguments `
        -Message 'A source object is read by its NameWithOwner, and without -Repository gh copies into the current repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a source that looks like an option, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Copy-GitHubLabel -Source '--force'
    } -MessageLike "*'--force' is not a repository*" -Message 'A source starting with a dash is refused'
    Assert-Throws -ScriptBlock {
        Copy-GitHubLabel -Source @()
    } -MessageLike '-Source is an empty list: give one repository, or leave it out.' `
        -Message 'An empty list of sources names -Source, not -Repository'
    Assert-Throws -ScriptBlock {
        Copy-GitHubLabel -Source 'cli/cli' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null destination throws instead of copying into the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside every other parameter, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(Copy-GitHubLabel -Source 'a/b' -Force -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no label is copied'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Copy-GitHubLabel -Source 'a/b' -Force -Repository 'o/r' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'clone', 'a/b', '--force', '--repo', 'o/r') -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false copy as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a destination given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Copy-GitHubLabel -Source 'a/b' -Repository $null -WhatIf
    } -MessageLike '-Repository was given, but it is $null*' -Message '-WhatIf still refuses a $null destination'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if line, with a credential in both repositories' URLs
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Copy-GitHubLabel -Source 'https://user:SENTINEL@ghe.example.com/a/b.git' -Force `
            -Repository ([PSCustomObject]@{ Url = 'https://user:SENTINEL@www.github.com/o/r' }) `
            -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Copy labels from ghe.example.com/a/b" on target "o/r".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names both repositories by name, without either credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
