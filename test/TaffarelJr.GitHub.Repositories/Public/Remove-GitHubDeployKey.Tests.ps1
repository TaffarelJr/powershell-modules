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
    Remove-GitHubDeployKey -Id 42 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'deploy-key', 'delete', '42', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The id is positional and the repository goes through --repo'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - keys listed from two repositories, as Get-GitHubDeployKey returns them
$listing = New-FakeGitHubCli -Output @('[{"id":5000000001,"title":"ci"}]')
try {
    $listed = @(
        Get-GitHubDeployKey -Repository 'other/repo'
        Get-GitHubDeployKey
    )
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli
try {
    # Act
    $listed | Remove-GitHubDeployKey
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped key is deleted in its own call'
    Assert-Equal -Expected @('repo', 'deploy-key', 'delete', '5000000001', '--repo', 'other/repo') `
        -Actual $calls[0].Arguments `
        -Message 'A key is deleted by its Id from the repository it was listed from'
    Assert-Equal -Expected @('repo', 'deploy-key', 'delete', '5000000001') -Actual $calls[1].Arguments `
        -Message 'and one listed from the current directory''s repository from the current one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listed key with its own repository named again, and with another one named
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Id = [long]7; Repository = 'other/repo' } | Remove-GitHubDeployKey -Repository 'Other/Repo'
    [PSCustomObject]@{ Id = [long]9; Repository = 'ghe.io/o/r' } | Remove-GitHubDeployKey -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $enterprise = @(Get-FakeGitHubCall -Fixture $fake)[1]

    # Assert
    Assert-Equal -Expected @('repo', 'deploy-key', 'delete', '7', '--repo', 'Other/Repo') -Actual $call.Arguments `
        -Message 'A -Repository that names the piped key''s own repository is used'
    Assert-Equal -Expected @('repo', 'deploy-key', 'delete', '9', '--repo', 'ghe.io/o/r') `
        -Actual $enterprise.Arguments `
        -Message 'and an enterprise key piped with OWNER/REPO is deleted on its own host'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]7; Repository = 'other/repo' } | Remove-GitHubDeployKey -Repository 'o/r'
    } -MessageLike 'Deploy key 7 is in other/repo, but -Repository names o/r: give one or the other.' `
        -Message 'while one naming another repository is refused, so a key of the same id there is not deleted'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]8; Repository = $null } | Remove-GitHubDeployKey -Repository 'x/y'
    } -MessageLike "Deploy key 8 was listed from the current directory's repository, but -Repository names x/y: leave -Repository off, or list the key with -Repository." `
        -Message 'as is one beside a key listed from the current directory''s repository'
    $savedHost = $env:GH_HOST
    $env:GH_HOST = $null
    try {
        Assert-Throws -ScriptBlock {
            [PSCustomObject]@{ Id = [long]6; Repository = 'o/r' } | Remove-GitHubDeployKey -Repository 'ghe.io/o/r'
        } -MessageLike 'Deploy key 6 is in github.com/o/r, but -Repository names ghe.io/o/r: give one or the other.' `
            -Message 'and one naming another host than the default one a key listed without a host is on'
    }
    finally {
        $env:GH_HOST = $savedHost
    }
    Assert-Equal -Expected 2 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of the refused keys'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - ids that are no key's, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubDeployKey -Id 0
    } -MessageLike "*'Id'*minimum allowed range of 1*" -Message 'An id of 0 is refused'
    Assert-Throws -ScriptBlock {
        Remove-GitHubDeployKey -Id -3
    } -MessageLike "*'Id'*minimum allowed range of 1*" `
        -Message 'a negative id is refused, which gh would read as an option'
    Assert-Throws -ScriptBlock {
        Remove-GitHubDeployKey -Id 1 -Repository $null
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
    $out = @(Remove-GitHubDeployKey -Id 42 -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no key is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Remove-GitHubDeployKey -Id 42 -Repository 'o/r' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'deploy-key', 'delete', '42', '--repo', 'o/r') -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false delete as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two listed keys piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $keys = @(
        [PSCustomObject]@{ Id = [long]7; Repository = 'o/r' }
        [PSCustomObject]@{ Id = [long]8; Repository = 'o/r' }
    )
    $out = @($keys | Remove-GitHubDeployKey -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped key is deleted'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a listed key piped beside another repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]7; Repository = 'other/repo' } | Remove-GitHubDeployKey -Repository 'o/r' -WhatIf
    } -MessageLike 'Deploy key 7 is in other/repo, but -Repository names o/r: give one or the other.' `
        -Message '-WhatIf still refuses a key listed from another repository than -Repository names'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two listed keys, one listed from a URL that carries a credential
$fake = New-FakeGitHubCli
try {
    # Act
    $keys = @(
        [PSCustomObject]@{ Id = [long]7; Repository = 'https://user:SENTINEL@github.com/o/r' }
        [PSCustomObject]@{ Id = [long]8; Repository = 'ghe.example.com/o/r' }
    )
    $result = Get-WhatIfOutput -ScriptBlock { $keys | Remove-GitHubDeployKey -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete deploy key" on target "o/r deploy key 7".'
        'What if: Performing the operation "Delete deploy key" on target "ghe.example.com/o/r deploy key 8".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped key gets its own line, in its repository, named without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
