#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubGistsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubGist -Id 'bcd1234567890abcdef0'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'delete', 'bcd1234567890abcdef0', '--yes') -Actual $call.Arguments `
        -Message 'The gist is deleted without prompting'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gist ids from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('a', 'b') | Remove-GitHubGist
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped gist is deleted in its own call'
    Assert-Equal -Expected @('gist', 'delete', 'b', '--yes') -Actual $calls[1].Arguments `
        -Message 'The second piped gist is deleted too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gists from a listing, piped in, and an object with only a Url
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = '[[{"id":"a1","html_url":"https://gist.github.com/me/a1"},{"id":"b2","html_url":"https://gist.github.com/me/b2"}]]' }
    @{ Output = @() }
)
try {
    # Act
    $gists = @(Get-GitHubGist -List)
    $gists | Remove-GitHubGist
    [PSCustomObject]@{ Url = 'https://api.github.com/gists/c3c3c3c3c3c3c3c3c3c3' } | Remove-GitHubGist
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('gist', 'delete', 'a1', '--yes') -Actual $calls[1].Arguments `
        -Message 'A listed gist is deleted by its Id'
    Assert-Equal -Expected @('gist', 'delete', 'b2', '--yes') -Actual $calls[2].Arguments `
        -Message 'and so is the next one'
    Assert-Equal -Expected @('gist', 'delete', 'c3c3c3c3c3c3c3c3c3c3', '--yes') -Actual $calls[3].Arguments `
        -Message 'and an object with only a Url is read by it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the gist given as a URL
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubGist -Id 'https://gist.github.com/me/bcd1234567890abcdef0'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'delete', 'bcd1234567890abcdef0', '--yes') -Actual $call.Arguments `
        -Message 'A gist URL is reduced to its bare id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that is not a gist, which must never reach a delete
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubGist -Id '--yes'
    } -MessageLike "*'--yes' is not a gist: give its id or URL, or a gist object." `
        -Message 'A value that is not an id is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh from before gist delete took --yes
$fake = New-FakeGitHubCli -ErrorOutput @('unknown flag: --yes') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubGist -Id 'bcd1234567890abcdef0'
    } -MessageLike '*Deleting gist bcd1234567890abcdef0 failed*unknown flag: --yes*' `
        -Message 'An old gh fails with its own message about the flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf on a gist given by URL
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubGist -Id 'https://gist.github.com/me/bcd1234567890abcdef0' -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Delete gist" on target "gist bcd1234567890abcdef0".') `
        -Actual $whatIf.Messages -Message '-WhatIf names the gist by its id'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and deletes nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a value that is not a gist
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubGist -Id '--yes' -WhatIf
    } -MessageLike "*'--yes' is not a gist: give its id or URL, or a gist object." `
        -Message '-WhatIf still refuses a value that is not a gist'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two gists piped under -WhatIf, one a gist object
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @('a1', [PSCustomObject]@{ Id = 'b2' }) | Remove-GitHubGist -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete gist" on target "gist a1".'
        'What if: Performing the operation "Delete gist" on target "gist b2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped gist'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and deletes neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a credential in a gist URL, given as text and as a gist
# object's Url
$fake = New-FakeGitHubCli
$url = 'https://user:SENTINEL@gist.github.com/me/bcd1234567890abcdef0'
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @($url, [PSCustomObject]@{ Url = $url }) | Remove-GitHubGist -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete gist" on target "gist bcd1234567890abcdef0".'
        'What if: Performing the operation "Delete gist" on target "gist bcd1234567890abcdef0".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names the gist by its id alone'
    Assert-Equal -Expected 0 -Actual @($whatIf.Messages -match 'SENTINEL').Count `
        -Message 'so no line holds the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and nothing is deleted'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
