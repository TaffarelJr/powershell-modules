#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    $run = Get-WhatIfOutput { Invoke-GitHubApi -Endpoint 'repos/o/r/issues/comments/1' -Method delete -WhatIf }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'A DELETE under -WhatIf runs no gh'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Call the GitHub API" on target "DELETE repos/o/r/issues/comments/1".'
    ) -Actual $run.Messages -Message 'and names the method and the endpoint'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    $run = Get-WhatIfOutput { Invoke-GitHubApi -Endpoint 'repos/o/r/issues' -RawField @{ title = 'x' } -WhatIf }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'Fields with no -Method, which gh sends as a POST, run no gh'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Call the GitHub API" on target "POST repos/o/r/issues".'
    ) -Actual $run.Messages -Message 'and the target names the POST gh would send'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    $run = Get-WhatIfOutput { Invoke-GitHubApi -Endpoint 'repos/o/r/rulesets' -Body '{"name":"x"}' -WhatIf }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count `
        -Message 'A -Body with no -Method, which gh sends as a POST, runs no gh'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Call the GitHub API" on target "POST repos/o/r/rulesets".'
    ) -Actual $run.Messages -Message 'and the target says POST'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{"default_branch":"main"}')
try {
    # Act
    $run = Get-WhatIfOutput { Invoke-GitHubApi -Endpoint 'repos/o/r' -WhatIf }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'A GET under -WhatIf still runs, since it changes nothing'
    Assert-Equal -Expected 'main' -Actual $run.Output[0].default_branch -Message 'and returns what it read'
    Assert-Equal -Expected 0 -Actual $run.Messages.Count -Message 'with no What if line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @()
try {
    # Act
    $run = Get-WhatIfOutput { Invoke-GitHubApi -Endpoint 'repos/o/r' -Method HEAD -Silent -WhatIf }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'A HEAD under -WhatIf still runs'
    Assert-Equal -Expected 0 -Actual $run.Messages.Count -Message 'with no What if line either'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{"data":{"viewer":{"login":"octocat"}}}')
try {
    # Act
    $run = Get-WhatIfOutput {
        Invoke-GitHubApi -Endpoint 'graphql' -RawField @{ query = 'query { viewer { login } }' } -WhatIf
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'A GraphQL query, which gh sends as a POST, still runs'
    Assert-Equal -Expected 'octocat' -Actual $run.Output[0].data.viewer.login -Message 'and returns its answer'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an endpoint that holds a GitHub token, built here so no literal in
# the repository looks like one
$token = 'ghp_' + ('A' * 36)
$fake = New-FakeGitHubCli -Output @('{}')
try {
    # Act
    $run = Get-WhatIfOutput { Invoke-GitHubApi -Endpoint "repos/o/r/hooks/$token" -Method DELETE -WhatIf }

    # Assert
    Assert-Equal -Expected 1 -Actual $run.Messages.Count -Message 'The What if line is written'
    Assert-That -Condition (-not $run.Messages[0].Contains($token)) -Message 'without the token in its target'
    Assert-That -Condition ($run.Messages[0] -like '*"DELETE repos/o/r/hooks/*') -Message 'but with the rest of it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a caller of its own, with -WhatIf, which a module function does not
# see unless it copies the caller's preference
function Remove-Comment {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'It stands for a caller given -WhatIf, so it must reach the command under test, not skip it.')]
    param()

    Invoke-GitHubApi -Endpoint 'repos/o/r/issues/comments/1' -Method DELETE
}
$fake = New-FakeGitHubCli -Output @('{}')

# Act
try {
    $run = Get-WhatIfOutput { Remove-Comment -WhatIf }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath Function:Remove-Comment
}

# Assert
Assert-Equal -Expected 0 -Actual $calls.Count -Message 'A caller''s -WhatIf reaches the DELETE, which runs no gh'
Assert-Equal -Expected 1 -Actual $run.Messages.Count -Message 'and says what it would have done'

exit (Complete-TestRun)
