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

# The real gh, talking to a loopback server: where a download lands and how a
# pattern matches is proved here, which the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$release = '{"id":1,"tag_name":"v1","assets":[' +
'{"id":9,"name":"a.txt","size":3,"url":"http://api.github.localhost/repos/o/r/releases/assets/9"},' +
'{"id":10,"name":"b.zip","size":3,"url":"http://api.github.localhost/repos/o/r/releases/assets/10"}]}'
$routes = [ordered]@{
    '/repos/o/r/releases/tags/v1'  = @{ Body = $release }
    '/repos/o/r/releases/assets/9' = @{ Body = 'abc' }
}

$folder = New-ReleaseTestFolder
$elsewhere = New-ReleaseTestFolder
$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - matching assets into a relative folder
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.txt' -Destination 'out' -Repository 'o/r'
    }

    # Assert
    Assert-Equal `
        -Expected 'abc' `
        -Actual (Get-Content -LiteralPath (Join-Path $folder 'out' 'a.txt') -Raw) `
        -Message 'The matching asset lands in the folder under PowerShell''s location'
    Assert-Equal `
        -Expected @('a.txt') `
        -Actual @((Get-ChildItem -LiteralPath (Join-Path $folder 'out')).Name) `
        -Message 'and nothing else does'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a pattern in another case
    Assert-Throws -ScriptBlock {
        Save-GitHubReleaseAsset -Tag 'v1' -Pattern '*.TXT' -Destination $elsewhere -Repository 'o/r'
    } -MessageLike '*no assets match the file pattern*' `
        -Message 'A pattern is matched case-sensitively, so *.TXT misses a.txt'
}
finally {
    Stop-FakeGitHubServer -Server $server
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

exit (Complete-TestRun)
