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
# Arrange - a key file, given by a relative path with the process elsewhere
$folder = Join-Path ([IO.Path]::GetTempPath()) "keys-$([Guid]::NewGuid())"
$elsewhere = Join-Path $folder 'elsewhere'
New-Item -ItemType Directory -Path $elsewhere | Out-Null
Set-Content -LiteralPath (Join-Path $folder 'id_ed25519.pub') -Value 'ssh-ed25519 AAAA'
$fake = New-FakeGitHubCli
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Add-GitHubDeployKey -KeyFile 'id_ed25519.pub' -Repository 'o/r' -Title '--' -AllowWrite
    }

    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'repo', 'deploy-key', 'add', (Join-Path $folder 'id_ed25519.pub'), '--title=--', '--allow-write', '--repo',
            'o/r'
        ) `
        -Actual $call.Arguments `
        -Message 'The key file goes as a full path from PowerShell''s location, the title joined to its flag so even -- stays a title'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a key file that is not there, a lone dash, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubDeployKey -KeyFile 'no-such-key.pub'
    } -MessageLike "-KeyFile 'no-such-key.pub' is not a file." `
        -Message 'A key file that is not there is refused with its name'
    Assert-Throws -ScriptBlock {
        Add-GitHubDeployKey -KeyFile '-'
    } -MessageLike "-KeyFile '-' would make gh read standard input: give the path of a file." `
        -Message 'A lone dash, which gh reads as standard input, is refused'
    Assert-Throws -ScriptBlock {
        Add-GitHubDeployKey -KeyFile 'no-such-key.pub' -Title ' '
    } -MessageLike '-Title is blank: give a title for the key, or leave it out.' `
        -Message 'A blank title is refused, not dropped or sent'
    Assert-Throws -ScriptBlock {
        Add-GitHubDeployKey -KeyFile 'no-such-key.pub' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of adding to the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside every other parameter, then -WhatIf:$false and -Confirm:$false
$folder = Join-Path ([IO.Path]::GetTempPath()) "keys-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$key = Join-Path $folder 'id_ed25519.pub'
Set-Content -LiteralPath $key -Value 'ssh-ed25519 AAAA'
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(Add-GitHubDeployKey -KeyFile $key -Title 'ci' -AllowWrite -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no key is added'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Add-GitHubDeployKey -KeyFile $key -Title 'ci' -AllowWrite -Repository 'o/r' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'deploy-key', 'add', $key, '--title=ci', '--allow-write', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false add the key as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a key file that is not there
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubDeployKey -KeyFile 'no-such-key.pub' -Repository 'o/r' -WhatIf
    } -MessageLike "-KeyFile 'no-such-key.pub' is not a file." `
        -Message '-WhatIf still refuses a key file that is not there'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if line, with a credential in -Repository's URL
$folder = Join-Path ([IO.Path]::GetTempPath()) "keys-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$key = Join-Path $folder 'id_ed25519.pub'
Set-Content -LiteralPath $key -Value 'ssh-ed25519 AAAA'
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubDeployKey -KeyFile $key -Title 'ci' -AllowWrite -Repository 'https://user:SENTINEL@github.com/o/r' `
            -WhatIf
    }

    # Assert
    $expected = "What if: Performing the operation `"Add deploy key from $key`" on target `"o/r`"."
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the key file and the repository, without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if line for the current directory's repository
$fake = New-FakeGitHubCli
$folder = Join-Path ([IO.Path]::GetTempPath()) "keys-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$key = Join-Path $folder 'id_ed25519.pub'
Set-Content -LiteralPath $key -Value 'ssh-ed25519 AAAA'
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock { Add-GitHubDeployKey -KeyFile $key -WhatIf }

    # Assert
    $expected = "What if: Performing the operation `"Add deploy key from $key`" on target" +
    " `"the current directory's repository`"."
    Assert-Equal -Expected @($expected) -Actual $result.Messages -Message 'An omitted repository is named in words'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
