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
    Remove-GitHubRepository -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'delete', 'o/r', '--yes') -Actual $call.Arguments `
        -Message 'The named repository is deleted without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('o/a', 'o/b') | Remove-GitHubRepository
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped repository is deleted in its own call'
    Assert-Equal -Expected @('repo', 'delete', 'o/b', '--yes') -Actual $calls[1].Arguments `
        -Message 'The second piped repository is deleted too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an enterprise repository object, and a list given where one repository is meant
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ NameWithOwner = 'o/r'; Url = 'https://ghe.example.com/o/r' } | Remove-GitHubRepository
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'delete', 'https://ghe.example.com/o/r', '--yes') -Actual $call.Arguments `
        -Message 'An object is read by its Url first, so the repository on its own host is deleted, not a namesake on github.com'
    Assert-Throws -ScriptBlock {
        Remove-GitHubRepository -Repository @('o/a', 'o/b')
    } -MessageLike 'Give one repository at a time, not a list of 2; call once per repository.' `
        -Message 'A list given as the parameter is refused, saying to call once per repository'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called for it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository that gh cannot delete
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 403: Must have admin rights to Repository') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubRepository -Repository 'o/r'
    } -MessageLike '*Deleting repository o/r failed*Must have admin rights*' `
        -Message 'A failure throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(Remove-GitHubRepository -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so the repository is not deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Remove-GitHubRepository -Repository 'o/r' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'delete', 'o/r', '--yes') -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false delete as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two repositories piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @('o/a', 'o/b' | Remove-GitHubRepository -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped repository is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a list given where one repository is meant
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubRepository -Repository @('o/a', 'o/b') -WhatIf
    } -MessageLike 'Give one repository at a time, not a list of 2; call once per repository.' `
        -Message '-WhatIf still refuses a list'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two repositories piped in, one an object whose Url carries a credential
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        'https://user:SENTINEL@github.com/o/a', [PSCustomObject]@{ Url = 'https://user:SENTINEL@ghe.example.com/o/b' } |
            Remove-GitHubRepository -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete repository" on target "o/a".'
        'What if: Performing the operation "Delete repository" on target "ghe.example.com/o/b".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped repository gets its own line, named without the credential its URL carried'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
