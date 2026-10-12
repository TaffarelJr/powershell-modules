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
    Rename-GitHubRepository -NewName 'renamed' -Repository 'o/r'
    Rename-GitHubRepository 'o/old' 'new'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'rename', 'renamed', '--yes', '--repo', 'o/r') -Actual $calls[0].Arguments `
        -Message 'The new name is gh''s operand and the repository goes through --repo, without prompting'
    Assert-Equal -Expected @('repo', 'rename', 'new', '--yes', '--repo', 'o/old') -Actual $calls[1].Arguments `
        -Message 'By position, the repository comes first and the new name second, as Rename-Item takes them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository object, as a listing returns it
$fake = New-FakeGitHubCli
try {
    # Act
    Rename-GitHubRepository -NewName 'renamed' `
        -Repository ([PSCustomObject]@{ NameWithOwner = 'o/r'; Url = 'https://ghe.example.com/o/r' })
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'rename', 'renamed', '--yes', '--repo', 'https://ghe.example.com/o/r') `
        -Actual $call.Arguments `
        -Message 'An object is read by its Url, not its text, so it is renamed on its own host'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no repository named, one given as $null, and a new name that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act
    $command = Get-Command -Name 'Rename-GitHubRepository'

    # Assert
    Assert-Equal -Expected $true `
        -Actual $command.Parameters['Repository'].Attributes.Where({ $_ -is [Parameter] })[0].Mandatory `
        -Message '-Repository is mandatory, so the current directory''s repository is never renamed by implication'
    Assert-Throws -ScriptBlock {
        Rename-GitHubRepository -NewName 'renamed' -Repository $null
    } -MessageLike "*Cannot bind argument to parameter 'Repository' because it is null*" `
        -Message 'A $null repository is refused'
    Assert-Throws -ScriptBlock {
        Rename-GitHubRepository -NewName '--yes' -Repository 'o/r'
    } -MessageLike "*'--yes' starts with '-', which gh would read as an option*" `
        -Message 'A name starting with a dash is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(Rename-GitHubRepository -Repository 'o/r' -NewName 'renamed' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so the repository is not renamed'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Rename-GitHubRepository -Repository 'o/r' -NewName 'renamed' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'rename', 'renamed', '--yes', '--repo', 'o/r') -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false rename as before, neither one reaching gh'
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
        Rename-GitHubRepository -Repository @('o/a', 'o/b') -NewName 'renamed' -WhatIf
    } -MessageLike 'Give one repository at a time, not a list of 2; call once per repository.' `
        -Message '-WhatIf still refuses a list'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if line, with a credential in -Repository's URL
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Rename-GitHubRepository -Repository 'https://user:SENTINEL@github.com/o/r' -NewName 'renamed' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Rename repository to renamed" on target "o/r".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the repository without the credential, and the new name'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
