#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubReleasesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubRelease -Tag 'v1.0.0' -CleanupTag -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'delete', '--yes', '--cleanup-tag', '--repo', 'o/r', '--', 'v1.0.0') `
        -Actual $call.Arguments `
        -Message 'The release is deleted without prompting, tag included, and the tag comes last, after a --'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - releases piped in as Get-GitHubRelease -List returns them in the current repository
$fake = New-FakeGitHubCli
try {
    # Act
    $listed = @(
        [PSCustomObject]@{ TagName = 'v1'; Name = 'One'; Repository = $null }
        [PSCustomObject]@{ TagName = 'v2'; Name = 'Two'; Repository = $null }
    )
    $listed | Remove-GitHubRelease
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped release is deleted in its own call'
    Assert-Equal `
        -Expected @('release', 'delete', '--yes', '--', 'v2') `
        -Actual $calls[1].Arguments `
        -Message 'The TagName is read from the piped object, not its text or title; a $null Repository means here'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release read from another repository, piped straight on
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = @('{"tagName":"v1.0.0","url":"https://github.com/other/repo/releases/tag/v1.0.0"}') }
    @{ Output = @() }
)
try {
    # Act
    Get-GitHubRelease -Tag 'v1.0.0' -Property 'tagName,url' | Remove-GitHubRelease
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('release', 'delete', '--yes', '--repo', 'other/repo', '--', 'v1.0.0') `
        -Actual $calls[1].Arguments `
        -Message 'The release is deleted in the repository it came from, not the current one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a tag that is a number, and one in a hashtable
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ TagName = 2 }, @{ TagName = 'v3' }) | Remove-GitHubRelease
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('2', 'v3') `
        -Actual @($calls[0].Arguments[-1], $calls[1].Arguments[-1]) `
        -Message 'Each is deleted by its TagName, not by its text'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an object with no TagName
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'x'; IsDraft = $true } | Remove-GitHubRelease
    } -MessageLike 'A release object needs a TagName*' `
        -Message 'An object with no tag is refused, not deleted by its text'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release from one repository and -Repository naming another
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' } | Remove-GitHubRelease -Repository 'c/d'
    } -MessageLike 'Release v1 is in a/b, but -Repository names c/d: give one or the other.' `
        -Message 'The two repositories disagreeing is refused'
    Assert-Throws -ScriptBlock {
        Remove-GitHubRelease -Tag 'v1' -Repository $null
    } -MessageLike "-Repository was given, but it is `$null - leave it out to use the current directory's repository." `
        -Message 'A -Repository given as $null is refused, not taken for the current one'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release from another repository given as -Tag, not piped
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubRelease -Tag ([PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' })
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'delete', '--yes', '--repo', 'a/b', '--', 'v1') `
        -Actual $call.Arguments `
        -Message 'A release given by name is deleted in the repository it came from too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a blank tag
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubRelease -Tag '  '
    } -MessageLike "'  ' is not a release tag*" -Message 'A blank tag is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - tags piped in as text, one that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act
    @('v1', '--web') | Remove-GitHubRelease
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('release', 'delete', '--yes', '--', '--web') `
        -Actual $calls[1].Arguments `
        -Message 'A tag piped in as text is an operand whatever it starts with'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the release is not there
$fake = New-FakeGitHubCli -ErrorOutput @('release not found') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubRelease -Tag 'v9'
    } -MessageLike '*Deleting release v9 failed*release not found*' `
        -Message 'A failure throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with -CleanupTag
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubRelease -Tag 'v1.0.0' -CleanupTag -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Delete release and its tag" on target "o/r release v1.0.0".'
    Assert-Equal -Expected @($expected) -Actual $result.Messages -Message '-WhatIf names the release and the change'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'gh is not called'
    Assert-Equal -Expected @() -Actual $result.Output -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with two releases listed in another repository, piped straight on
$fake = New-FakeGitHubCli -Output @(
    '[{"tagName":"v1","url":"https://github.com/other/repo/releases/tag/v1"},' +
    '{"tagName":"v2","url":"https://github.com/other/repo/releases/tag/v2"}]'
)
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Get-GitHubRelease -List -Property 'tagName' -Repository 'other/repo' | Remove-GitHubRelease -WhatIf
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete release" on target "other/repo release v1".'
        'What if: Performing the operation "Delete release" on target "other/repo release v2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped release is named in the repository it came from'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'and gh is called only to list them'
    Assert-Equal -Expected 'list' -Actual $calls[0].Arguments[1] -Message 'which is the listing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a release from one repository and -Repository naming another
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' } | Remove-GitHubRelease -Repository 'c/d' -WhatIf
    } -MessageLike 'Release v1 is in a/b, but -Repository names c/d: give one or the other.' `
        -Message 'The mismatch is still refused under -WhatIf'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a credential in -Repository's URL and in a piped release's Repository
$fake = New-FakeGitHubCli
$sentinel = 'SENTINEL'
$listed = [PSCustomObject]@{ TagName = 'v1'; Repository = "https://user:$sentinel@github.com/o/r" }
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        $listed, 'v2' | Remove-GitHubRelease -Repository "https://user:$sentinel@www.github.com/o/r.git" -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete release" on target "o/r release v1".'
        'What if: Performing the operation "Delete release" on target "o/r release v2".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each release is named in OWNER/REPO, the credential and the www. left out'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
