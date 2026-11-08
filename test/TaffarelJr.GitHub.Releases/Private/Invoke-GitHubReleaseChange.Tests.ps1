#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$manifest = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1'
$module = Import-Module $manifest -Force -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - notes, with the URL among gh's progress lines
$fake = New-FakeGitHubCli -Output @('Uploading a.zip', 'https://github.com/o/r/releases/tag/v1', 'done')
try {
    # Act
    $url = & $module {
        $change = @{
            Activity   = 'Editing release v1'
            Option     = 'release', 'edit', '--draft=false'
            Operand    = 'v1'
            Repository = 'o/r'
            Notes      = "a`nb"
        }
        Invoke-GitHubReleaseChange @change
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $file = $call.Arguments[4]

    # Assert
    Assert-Equal `
        -Expected @('release', 'edit', '--draft=false', '--notes-file', $file, '--repo', 'o/r', '--', 'v1') `
        -Actual $call.Arguments `
        -Message 'The notes file goes with the options, before the -- and the operands'
    Assert-Equal `
        -Expected "a`nb" `
        -Actual $call.Files[$file] `
        -Message 'and holds the notes exactly, with no newline added'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped'
    Assert-Equal `
        -Expected 'https://github.com/o/r/releases/tag/v1' `
        -Actual $url `
        -Message 'The URL gh prints is returned, and only that'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $file) -Message 'The notes file is gone afterwards'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - empty notes
$fake = New-FakeGitHubCli
try {
    # Act
    & $module {
        Invoke-GitHubReleaseChange -Activity 'Editing release v1' -Option 'release', 'edit' -Operand 'v1' -Notes ''
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected '' `
        -Actual $call.Files[$call.Arguments[3]] `
        -Message 'Empty notes are an empty file, which clears the release''s notes'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no notes, and no URL in gh's output
$fake = New-FakeGitHubCli -Output @('nothing to see')
try {
    # Act
    $result = @(& $module {
            $change = @{
                Activity = 'Creating release v2'
                Option   = 'release', 'create'
                Operand  = 'v2', 'a.zip'
            }
            Invoke-GitHubReleaseChange @change
        })
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'create', '--', 'v2', 'a.zip') `
        -Actual $call.Arguments `
        -Message 'Without notes no notes file is passed'
    Assert-Equal -Expected 0 -Actual $result.Count -Message 'and with no URL printed, nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
