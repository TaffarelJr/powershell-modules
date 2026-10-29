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
# Arrange - a fork of a named repository, nothing local
$fake = New-FakeGitHubCli -Output @('https://github.com/me/r')
try {
    # Act
    $url = New-GitHubFork -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'fork', 'o/r', '--clone=false') -Actual $call.Arguments `
        -Message 'A named repository is forked with cloning declined and nothing about a remote, which gh refuses beside a repository'
    Assert-Equal -Expected 'https://github.com/me/r' -Actual $url -Message 'The new fork''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a named repository cloned under another name in an organization, with clone chatter
$fake = New-FakeGitHubCli -Output @('Cloning into ''mine''...', 'https://github.com/org/mine')
try {
    # Act
    $url = New-GitHubFork -Repository 'o/r' -Organization 'org' -ForkName 'mine' -DefaultBranchOnly -Clone
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('repo', 'fork', 'o/r', '--clone=true', '--org=org', '--fork-name=mine', '--default-branch-only') `
        -Actual $call.Arguments `
        -Message 'Each option for a named repository becomes its gh flag'
    Assert-Equal -Expected 'https://github.com/org/mine' -Actual $url `
        -Message 'The URL is picked out from among other output lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository, added as a remote
$fake = New-FakeGitHubCli -Output @('https://github.com/me/here')
try {
    # Act
    New-GitHubFork -Remote -RemoteName 'fork' | Out-Null
    New-GitHubFork | Out-Null
    New-GitHubFork -Repository 'o/r' -ForkName '-x' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'fork', '--clone=false', '--remote=true', '--remote-name=fork') `
        -Actual $calls[0].Arguments `
        -Message 'Without -Repository, -Remote and -RemoteName become their gh flags'
    Assert-Equal -Expected @('repo', 'fork', '--clone=false', '--remote=false') -Actual $calls[1].Arguments `
        -Message 'and with neither, adding a remote is declined in so many words'
    Assert-Equal -Expected @('repo', 'fork', 'o/r', '--clone=false', '--fork-name=-x') -Actual $calls[2].Arguments `
        -Message 'A fork name travels joined to its flag, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fork that already existed, which gh only reports on standard error
$fake = New-FakeGitHubCli -ErrorOutput @('me/r already exists')
try {
    # Act
    $url = @(New-GitHubFork -Repository 'o/r')

    # Assert
    Assert-Equal -Expected 0 -Actual $url.Count -Message 'No URL printed returns nothing, not $null'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a remote asked for beside a named repository, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r' -Remote
    } -MessageLike '*-Remote and -RemoteName add a remote to the current directory''s clone*gh refuses them with a named repository.' `
        -Message '-Remote with a named repository is refused, as gh would refuse it'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r' -Remote:$false
    } -MessageLike '*-Remote and -RemoteName*' -Message 'even -Remote:$false, which gh refuses too'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r' -RemoteName 'fork'
    } -MessageLike '*-Remote and -RemoteName*' -Message 'and -RemoteName, which gh would silently ignore'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -RemoteName 'fork'
    } -MessageLike '-RemoteName works only with -Remote: it names the remote -Remote adds, and gh ignores it otherwise. Give -Remote too, or leave -RemoteName off.' `
        -Message '-RemoteName without -Remote is refused, rather than silently adding no remote'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Remote:$false -RemoteName 'fork'
    } -MessageLike '-RemoteName works only with -Remote:*' -Message 'as is -RemoteName beside -Remote:$false'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r' -Organization '-x'
    } -MessageLike "*'-x' is not an organization name: give letters, digits, and dashes." `
        -Message 'An organization name that is not one is refused, by the rule every -Organization here uses'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r' -Organization ''
    } -MessageLike '-Organization was given but is blank, so the fork would go to your own account. Give a value, or leave -Organization off.' `
        -Message 'A blank organization is refused, not taken as the authenticated user'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r' -ForkName ' '
    } -MessageLike '-ForkName was given but is blank, so the fork would keep the original name. Give a value, or leave -ForkName off.' `
        -Message 'as is a blank fork name'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Remote -RemoteName ''
    } -MessageLike '-RemoteName was given but is blank, so gh would name the remote origin. Give a value, or leave -RemoteName off.' `
        -Message 'and a blank remote name'
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository $null
    } -MessageLike "-Repository was given, but it is `$null - leave it out to use the current directory's repository." `
        -Message 'A $null repository throws instead of forking the current directory''s'
    Assert-Throws -ScriptBlock {
        $null | New-GitHubFork
    } -MessageLike '-Repository was given, but it is $null*' -Message 'as does a piped $null'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh failing to fork a named repository and the current one
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 404: Not Found') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r'
    } -MessageLike 'Forking repository o/r failed*Not Found*' -Message 'A failure names the repository being forked'
    Assert-Throws -ScriptBlock {
        New-GitHubFork
    } -MessageLike 'Forking the current directory''s repository failed*Not Found*' `
        -Message 'or says it was the current directory''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside every other parameter, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli -Output @('https://github.com/org/mine')
try {
    # Act
    $out = @(New-GitHubFork -Repository 'o/r' -Organization 'org' -ForkName 'mine' -DefaultBranchOnly -Clone -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so nothing is forked'
    Assert-Equal -Expected @() -Actual $out -Message 'and no URL is returned'

    # Act
    $url = New-GitHubFork -Repository 'o/r' -Organization 'org' -ForkName 'mine' -DefaultBranchOnly -Clone `
        -WhatIf:$false `
        -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('repo', 'fork', 'o/r', '--clone=true', '--org=org', '--fork-name=mine', '--default-branch-only') `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false fork as before, neither one reaching gh'
    Assert-Equal -Expected 'https://github.com/org/mine' -Actual $url -Message 'and the URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two repositories piped in with -WhatIf, and the current directory's with a remote
$fake = New-FakeGitHubCli -Output @('https://github.com/me/r')
try {
    # Act
    $out = @(
        'o/a', 'o/b' | New-GitHubFork -WhatIf
        New-GitHubFork -Remote -RemoteName 'fork' -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf no piped repository is forked, nor the current one'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a remote asked for beside a named repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubFork -Repository 'o/r' -Remote -WhatIf
    } -MessageLike '*-Remote and -RemoteName add a remote to the current directory''s clone*' `
        -Message '-WhatIf still refuses -Remote beside a named repository'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines: each local change named, PowerShell's location apart from the process's
$folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "fork-$([Guid]::NewGuid())")
$elsewhere = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "fork-$([Guid]::NewGuid())")
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Use-SplitLocation -Location $folder.FullName -ProcessDirectory $elsewhere.FullName -ScriptBlock {
            New-GitHubFork -Repository 'https://user:SENTINEL@github.com/o/r' -Organization 'org' -ForkName 'mine' `
                -DefaultBranchOnly `
                -Clone `
                -WhatIf
            New-GitHubFork -Remote -Clone -WhatIf
            New-GitHubFork -Remote -RemoteName 'fork' -WhatIf
        }
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Fork repository into organization org as mine, cloning it into a new' +
        " folder in $($folder.FullName)`" on target `"o/r`"."
        "What if: Performing the operation `"Fork repository, adding it as remote origin of $($folder.FullName)," +
        " renaming an existing origin to upstream`" on target `"the current directory's repository`"."
        "What if: Performing the operation `"Fork repository, adding it as remote fork of $($folder.FullName)`"" +
        " on target `"the current directory's repository`"."
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message ('-WhatIf names where the fork goes, the clone''s folder and the remote, in PowerShell''s location;' +
            ' no clone is named for the current repository''s fork, which gh does not clone; no credential shows')
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two repositories piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock { 'o/a', 'https://github.com/o/b' | New-GitHubFork -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Fork repository" on target "o/a".'
        'What if: Performing the operation "Fork repository" on target "o/b".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages -Message 'Each piped repository gets its own line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
