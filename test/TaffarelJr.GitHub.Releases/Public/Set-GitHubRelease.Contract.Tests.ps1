#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server: what gh sends GitHub for the
# notes and the title is proved here, which the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$release = '{"id":1,"tag_name":"v1","name":"One","body":"old",' +
'"html_url":"http://github.localhost/o/r/releases/tag/v1"}'
$routes = [ordered]@{
    '/repos/o/r/releases/tags/v1' = @{ Body = $release }
    '/repos/o/r/releases/1'       = @{ Body = $release }
}

$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - notes with mixed line endings and non-ASCII text, and a title of --
    $url = Set-GitHubRelease -Tag 'v1' -Title '--' -Notes "-a`r`nb ü`nc" -Repository 'o/r'
    $edit = @(Get-FakeGitHubRequest -Server $server)[-1]
    $body = $edit.Text | ConvertFrom-Json -AsHashtable

    # Assert
    Assert-Equal `
        -Expected 'PATCH /repos/o/r/releases/1' `
        -Actual "$($edit.Method) $($edit.Path)" `
        -Message 'gh edits the release in the repository named'
    Assert-Equal `
        -Expected "-a`r`nb ü`nc" `
        -Actual $body['body'] `
        -Message 'The notes reach GitHub exactly, with no newline added'
    Assert-Equal -Expected '--' -Actual $body['name'] -Message 'A title of -- is the title, not the end of the options'
    Assert-Equal `
        -Expected 'http://github.localhost/o/r/releases/tag/v1' `
        -Actual $url `
        -Message 'The URL gh prints is returned'

    #───────────────────────────────────────────────────────────────────────────
    # Act - clearing the title and the notes
    Set-GitHubRelease -Tag 'v1' -Title '' -Notes '' -Repository 'o/r' | Out-Null
    $edit = @(Get-FakeGitHubRequest -Server $server)[-1]
    $body = $edit.Text | ConvertFrom-Json -AsHashtable

    # Assert
    Assert-Equal `
        -Expected @('', '') `
        -Actual @($body['name'], $body['body']) `
        -Message 'An empty title and empty notes are sent empty, which clears them'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
