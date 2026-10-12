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
    Remove-GitHubLabel -Name 'wontfix' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'delete', '--yes', '--repo', 'o/r', '--', 'wontfix') -Actual $call.Arguments `
        -Message 'The label is deleted without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('a', 'b') | Remove-GitHubLabel
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped name is deleted in its own call'
    Assert-Equal -Expected @('label', 'delete', '--yes', '--', 'b') -Actual $calls[1].Arguments `
        -Message 'in the current directory''s repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - labels listed from other repositories, as Get-GitHubLabel returns them
$listing = New-FakeGitHubCli -Sequence @(
    @{ Output = @('[{"name":"bug","url":"https://github.com/other/repo/labels/bug"}]') }
    @{ Output = @('[{"name":"bug","url":"https://ghe.example.com/o/r/labels/bug"}]') }
)
try {
    $listed = @(
        Get-GitHubLabel -Repository 'other/repo'
        Get-GitHubLabel -Repository 'ghe.example.com/o/r'
    )
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli
try {
    # Act
    $listed | Remove-GitHubLabel
    $listed[1] | Remove-GitHubLabel -Repository 'ghe.example.com/o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('label', 'delete', '--yes', '--repo', 'https://github.com/other/repo', '--', 'bug') `
        -Actual $calls[0].Arguments `
        -Message 'A piped label is deleted from the repository its Url names, not the current one'
    Assert-Equal -Expected @('label', 'delete', '--yes', '--repo', 'https://ghe.example.com/o/r', '--', 'bug') `
        -Actual $calls[1].Arguments `
        -Message 'an enterprise one on its own host'
    Assert-Equal -Expected @('label', 'delete', '--yes', '--repo', 'ghe.example.com/o/r', '--', 'bug') `
        -Actual $calls[2].Arguments `
        -Message 'and a repository named as a parameter that agrees with the label''s own, host included, is used as named'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a label given by its URL, and an issue's label, which carries no Url, with its repository named
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubLabel -Name 'https://github.com/a/b/labels/good%20first%20issue'
    [PSCustomObject]@{ Id = 'LA_1'; Name = 'bug'; Color = 'fff'; Description = '' } | Remove-GitHubLabel `
        -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('label', 'delete', '--yes', '--repo', 'https://github.com/a/b', '--', 'good first issue') `
        -Actual $calls[0].Arguments `
        -Message 'A label''s URL is deleted from the repository it names, by its decoded name, not taken as a name'
    Assert-Equal -Expected @('label', 'delete', '--yes', '--repo', 'o/r', '--', 'bug') -Actual $calls[1].Arguments `
        -Message 'A label object with no Url is deleted from the repository named'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - things that name no label, labels from another repository than the one named, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        $listed[1] | Remove-GitHubLabel -Repository 'github.com/o/r'
    } -MessageLike "'https://ghe.example.com/o/r/labels/bug' is in ghe.example.com/o/r, but -Repository names github.com/o/r: give one or the other." `
        -Message 'An enterprise label is refused when -Repository names another host, so its namesake on github.com is not deleted'
    Assert-Throws -ScriptBlock {
        $listed[0] | Remove-GitHubLabel -Repository 'o/r'
    } -MessageLike "'https://github.com/other/repo/labels/bug' is in other/repo, but -Repository names o/r: give one or the other." `
        -Message 'A piped label from another repository than -Repository names is refused, naming both'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Title = 'x' } | Remove-GitHubLabel
    } -MessageLike 'A label object needs a Name, and this one has none: PSCustomObject.' `
        -Message 'An object with no Name is refused, not deleted by its text'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = 'LA_1'; Name = 'bug'; Color = 'fff' } | Remove-GitHubLabel
    } -MessageLike "The label 'bug' is an object with no Url, so it does not say its repository: give -Repository." `
        -Message 'An issue''s label with no repository named is refused, not deleted from the current directory''s'
    Assert-Throws -ScriptBlock {
        Remove-GitHubLabel -Name 'https://github.com/a/b/labels/bug' -Repository 'c/d'
    } -MessageLike "'https://github.com/a/b/labels/bug' is in a/b, but -Repository names c/d: give one or the other." `
        -Message 'A label''s URL from another repository than -Repository names is refused'
    Assert-Throws -ScriptBlock {
        Remove-GitHubLabel -Name 'bug' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of deleting from the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside -Repository, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(Remove-GitHubLabel -Name 'wontfix' -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no label is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Remove-GitHubLabel -Name 'wontfix' -Repository 'o/r' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'delete', '--yes', '--repo', 'o/r', '--', 'wontfix') -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false delete as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two labels piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @('a', 'b' | Remove-GitHubLabel -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped label is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a label's URL from another repository than -Repository names
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubLabel -Name 'https://github.com/a/b/labels/bug' -Repository 'c/d' -WhatIf
    } -MessageLike "'https://github.com/a/b/labels/bug' is in a/b, but -Repository names c/d: give one or the other." `
        -Message '-WhatIf still refuses a label from another repository'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two labels piped in: a name, and a label URL that carries a credential
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        'a', 'https://user:SENTINEL@github.com/o/r/labels/b' | Remove-GitHubLabel -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete label" on target "label a".'
        'What if: Performing the operation "Delete label" on target "o/r label b".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped label gets its own line, a URL''s in its repository, named without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
