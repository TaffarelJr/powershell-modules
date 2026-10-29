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

# The real gh, talking to a loopback server: whether gh takes a path literally
# is proved here, which the in-process fake gh cannot show.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$release = '{"id":1,"tag_name":"v1","assets":[],' +
'"upload_url":"http://api.github.localhost/repos/o/r/releases/1/assets{?name,label}"}'
$routes = [ordered]@{
    '/repos/o/r/releases/tags/v1'  = @{ Body = $release }
    '/repos/o/r/releases/1/assets*' = @{ Status = 201; Body = '{"id":5}' }
}

$folder = New-ReleaseTestFolder -File 'a[1].zip', 'C#/b.zip'
$elsewhere = New-ReleaseTestFolder
$server = Start-FakeGitHubServer -Route $routes
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a file whose name gh would read as a wildcard pattern
    Add-GitHubReleaseAsset -Tag 'v1' -LiteralPath (Join-Path $folder 'a[1].zip') -Repository 'o/r'
    $upload = @(Get-FakeGitHubRequest -Server $server)[-1]

    # Assert
    Assert-Equal `
        -Expected 'POST /repos/o/r/releases/1/assets?label=&name=a%5B1%5D.zip' `
        -Actual "$($upload.Method) $($upload.Path)" `
        -Message 'gh uploads the file by its literal name, with no label'
    Assert-Equal -Expected "x$([Environment]::NewLine)" -Actual $upload.Text -Message 'and sends that file''s content'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a relative path in a folder whose name holds a #, from inside it
    Use-SplitLocation -Location (Join-Path $folder 'C#') -ProcessDirectory $elsewhere -ScriptBlock {
        Get-ChildItem -LiteralPath (Join-Path $folder 'C#') | Add-GitHubReleaseAsset -Tag 'v1' -Repository 'o/r'
    }
    $upload = @(Get-FakeGitHubRequest -Server $server)[-1]

    # Assert
    Assert-Equal `
        -Expected 'POST /repos/o/r/releases/1/assets?label=&name=b.zip' `
        -Actual "$($upload.Method) $($upload.Path)" `
        -Message 'gh finds the file in PowerShell''s location, the # in its folder avoided'
}
finally {
    Stop-FakeGitHubServer -Server $server
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

exit (Complete-TestRun)
