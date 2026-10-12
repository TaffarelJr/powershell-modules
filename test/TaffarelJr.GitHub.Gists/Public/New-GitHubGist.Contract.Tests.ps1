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

# The real gh, talking to a loopback server: the bytes of the request GitHub
# would get, which the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$routes = [ordered]@{
    '/gists' = @{ Status = 201; Body = '{"id":"abc123","html_url":"https://gist.github.localhost/me/abc123"}' }
}
$folder = New-GistTestFolder -File @{ 'a.txt' = "line 1`nliné ✓" }
$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with line feeds and characters beyond ASCII, from a
    # caller whose $OutputEncoding writes a byte-order mark
    $saved = $OutputEncoding
    $OutputEncoding = [System.Text.UTF8Encoding]::new($true)
    try {
        # Act
        $url = New-GitHubGist -Path (Join-Path $folder 'a.txt')
    }
    finally {
        $OutputEncoding = $saved
    }

    $request = @(Get-FakeGitHubRequest -Server $server)[-1]
    $json = '{"description":"","files":{"a.txt":{"content":"line 1\nliné ✓"}},"public":false}'
    $expected = [System.Text.Encoding]::UTF8.GetBytes($json + [Environment]::NewLine)

    # Assert
    Assert-Equal -Expected 'POST /gists' -Actual "$($request.Method) $($request.Path)" `
        -Message 'The gist is created with a POST to gists'
    Assert-Equal -Expected ([Convert]::ToHexString($expected)) -Actual ([Convert]::ToHexString($request.Body)) `
        -Message 'whose body holds the file''s exact content, as UTF-8 with no byte-order mark'
    Assert-Equal -Expected 'https://gist.github.localhost/me/abc123' -Actual $url `
        -Message 'and the html_url GitHub answers with is returned'

    #───────────────────────────────────────────────────────────────────────────
    # Act - gh gist create, given the same file
    Invoke-GitHubCommand -Activity 'Creating with gh' -Arguments @(
        'gist', 'create', (Join-Path $folder 'a.txt')
    ) | Out-Null
    $request = @(Get-FakeGitHubRequest -Server $server)[-1]

    # Assert
    Assert-Equal `
        -Expected '{"description":"","files":{"a.txt":{"content":"line 1\nliné ✓"}},"updated_at":"0001-01-01T00:00:00Z","public":false}' `
        -Actual $request.Text.TrimEnd("`n") `
        -Message 'gh''s own request has the same description, files and public fields, plus a zero updated_at, which the create endpoint does not take'
}
finally {
    Stop-FakeGitHubServer -Server $server
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
