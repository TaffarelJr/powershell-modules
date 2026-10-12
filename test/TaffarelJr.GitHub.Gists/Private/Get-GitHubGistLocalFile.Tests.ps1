#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubGistsTestHelper.ps1')

# The case-insensitive match is pinned by New-GitHubGist.CaseInsensitive.Tests,
# which needs such a file system.
$folder = New-GistTestFolder -File @{ 'Notes.md' = 'N'; 'notes.txt' = 'n' }
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $exact = & $module { param($p) Get-GitHubGistLocalFile -Path $p -Source "'Notes.md'" } (Join-Path $folder 'Notes.md')

    # Assert
    Assert-Equal -Expected (Join-Path $folder 'Notes.md') -Actual $exact `
        -Message 'A name that is the file''s own is returned as it is'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a name no entry of the folder has, in any case
    Assert-Throws -ScriptBlock {
        & $module { param($p) Get-GitHubGistLocalFile -Path $p -Source "-AddFile 'Notes.md.'" } (Join-Path $folder 'Notes.md.')
    } -MessageLike "-AddFile 'Notes.md.' is not a file." `
        -Message 'is refused, named as the caller gave it, never guessed at'
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
