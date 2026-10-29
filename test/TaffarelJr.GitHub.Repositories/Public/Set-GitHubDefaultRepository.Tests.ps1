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
    Set-GitHubDefaultRepository -Repository 'o/r'
    Set-GitHubDefaultRepository -Repository ([PSCustomObject]@{ NameWithOwner = 'o/listed' })
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'set-default', 'o/r') -Actual $calls[0].Arguments `
        -Message 'The repository is passed positionally'
    Assert-Equal -Expected @('repo', 'set-default', 'o/listed') -Actual $calls[1].Arguments `
        -Message 'A repository object is read by its NameWithOwner, not its text'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - clearing it
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubDefaultRepository -Unset
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'set-default', '--unset') -Actual $call.Arguments `
        -Message '-Unset clears the default instead'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubDefaultRepository -Repository '--unset'
    } -MessageLike "*'--unset' is not a repository*" `
        -Message 'A repository starting with a dash is refused, so it cannot turn into --unset'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf setting and unsetting, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(
        Set-GitHubDefaultRepository -Repository 'o/r' -WhatIf
        Set-GitHubDefaultRepository -Unset -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls `
        -Message 'With -WhatIf gh is not called, so the default is neither set nor unset'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Set-GitHubDefaultRepository -Repository 'o/r' -WhatIf:$false -Confirm:$false
    Set-GitHubDefaultRepository -Unset -WhatIf:$false -Confirm:$false
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'set-default', 'o/r') -Actual $calls[0].Arguments `
        -Message '-WhatIf:$false and -Confirm:$false set it as before, neither one reaching gh'
    Assert-Equal -Expected @('repo', 'set-default', '--unset') -Actual $calls[1].Arguments -Message 'and unset it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a repository that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubDefaultRepository -Repository '--unset' -WhatIf
    } -MessageLike "*'--unset' is not a repository*" -Message '-WhatIf still refuses a repository starting with a dash'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines: the clone by its full path, PowerShell's location apart from the process's
$folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "clone-$([Guid]::NewGuid())")
$elsewhere = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "clone-$([Guid]::NewGuid())")
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Use-SplitLocation -Location $folder.FullName -ProcessDirectory $elsewhere.FullName -ScriptBlock {
            Set-GitHubDefaultRepository -Repository 'https://user:SENTINEL@ghe.example.com/o/r' -WhatIf
            Set-GitHubDefaultRepository -Unset -WhatIf
        }
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Set the default repository to ghe.example.com/o/r" on target' +
        " `"$($folder.FullName)`"."
        "What if: Performing the operation `"Unset the default repository`" on target `"$($folder.FullName)`"."
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names the clone by PowerShell''s location, and the repository without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

exit (Complete-TestRun)
