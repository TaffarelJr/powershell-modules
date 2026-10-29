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
    New-GitHubLabel -Name 'needs fix' -Color 'E99695' -Description 'Conflicts to resolve' -Force -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'label', 'create', '--color=E99695', '--description=Conflicts to resolve', '--force', '--repo', 'o/r', '--',
            'needs fix'
        ) `
        -Actual $call.Arguments `
        -Message 'The name is an operand and each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - just a name, a name that looks like an option, and a description that is only --
$fake = New-FakeGitHubCli
try {
    # Act
    New-GitHubLabel -Name 'bug'
    New-GitHubLabel -Name '--force'
    New-GitHubLabel -Name 'odd' -Description '--'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('label', 'create', '--', 'bug') -Actual $calls[0].Arguments `
        -Message 'Without options, gh picks the color'
    Assert-Equal -Expected @('label', 'create', '--', '--force') -Actual $calls[1].Arguments `
        -Message 'A name is an operand whatever it starts with, so it cannot turn into --force'
    Assert-Equal -Expected @('label', 'create', '--description=--', '--', 'odd') -Actual $calls[2].Arguments `
        -Message 'A description travels joined to its flag, so even -- stays a description'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -Force without a color, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name 'bug' -Description 'd' -Force
    } -MessageLike "-Force works only with -Color: without one gh would recolor an existing 'bug' at random. Give -Color too, or leave -Force off." `
        -Message '-Force without -Color is refused, since gh would give the existing label a random color'
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name 'bug' -Color ' ' -Force
    } -MessageLike '-Color is blank: give six hex digits, or leave it out.' `
        -Message 'A blank color is refused before the -Force rule, which it would otherwise pass'
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name 'bug' -Color '' -Force
    } -MessageLike '-Color is blank: give six hex digits, or leave it out.' `
        -Message 'as is an empty one, rather than saying -Color is missing'
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name 'bug' -Description ' '
    } -MessageLike '-Description is blank: give the description, or leave it out.' -Message 'and a blank description'
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name ' '
    } -MessageLike "*-Name is blank: give the label's name." -Message 'A blank name is refused, not sent to gh'
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name ''
    } -MessageLike "*-Name is blank: give the label's name." -Message 'as is an empty one'
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name 'bug' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of creating the label in the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside every other parameter, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(New-GitHubLabel -Name 'bug' -Color 'E99695' -Description 'd' -Force -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no label is created'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    New-GitHubLabel -Name 'bug' -Color 'E99695' -Description 'd' -Force -Repository 'o/r' -WhatIf:$false `
        -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('label', 'create', '--color=E99695', '--description=d', '--force', '--repo', 'o/r', '--', 'bug') `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false create as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with -Force and no color
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubLabel -Name 'bug' -Force -WhatIf
    } -MessageLike '-Force works only with -Color:*' -Message '-WhatIf still refuses -Force without -Color'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines, with and without -Force and a credential in -Repository's URL
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        New-GitHubLabel -Name 'bug' -Color 'E99695' -Description 'd' -Force `
            -Repository 'https://user:SENTINEL@github.com/o/r' `
            -WhatIf
        New-GitHubLabel -Name 'bug' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Create or update label" on target "o/r label bug".'
        'What if: Performing the operation "Create label" on target "label bug".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names the label in its repository, without the credential, and what -Force adds'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
