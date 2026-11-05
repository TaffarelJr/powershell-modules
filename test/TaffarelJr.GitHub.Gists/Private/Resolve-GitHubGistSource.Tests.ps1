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

$files = @{
    'b.md'     = 'b'
    'a.md'     = 'a'
    '.h.md'    = 'h'
    'c.txt'    = 'c'
    'a[1].txt' = 'x'
}
$folder = New-GistTestFolder -File $files -Folder @('sub.md')
$elsewhere = [System.IO.Path]::GetTempPath()
# Hidden by its leading dot off Windows, and by this attribute on it.
$hidden = Get-Item -LiteralPath (Join-Path $folder '.h.md') -Force
$hidden.Attributes = $hidden.Attributes -bor [System.IO.FileAttributes]::Hidden
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $resolved = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        [PSCustomObject]@{
            Wildcard = @(& $module { Resolve-GitHubGistSource -Path '*.md' })
            Literal  = @(& $module { Resolve-GitHubGistSource -Path 'c.txt' })
            Escaped  = @(& $module { Resolve-GitHubGistSource -Path 'a`[1`].txt' })
        }
    }

    # Assert
    Assert-Equal -Expected @((Join-Path $folder 'a.md'), (Join-Path $folder 'b.md')) `
        -Actual @($resolved.Wildcard.Path) `
        -Message 'A wildcard gives the full path of each file it matches, hidden ones and folders aside, from PowerShell''s location'
    Assert-Equal -Expected @("'$(Join-Path $folder 'a.md')'", "'$(Join-Path $folder 'b.md')'") `
        -Actual @($resolved.Wildcard.Source) `
        -Message 'and names each by its full path, as none was typed'
    Assert-Equal -Expected @(Join-Path $folder 'c.txt') -Actual @($resolved.Literal.Path) `
        -Message 'A path with no wildcard gives that one file'
    Assert-Equal -Expected @("'c.txt'") -Actual @($resolved.Literal.Source) -Message 'named as it was typed'
    Assert-Equal -Expected @(Join-Path $folder 'a[1].txt') -Actual @($resolved.Escaped.Path) `
        -Message 'and so does one whose wildcard characters are escaped'
    Assert-Equal -Expected @("'a``[1``].txt'") -Actual @($resolved.Escaped.Source) `
        -Message 'named as typed, escapes and all'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - paths that give no file
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Assert-Throws -ScriptBlock {
            & $module { Resolve-GitHubGistSource -Path 'sub.md' }
        } -MessageLike "'sub.md' is not a file." -Message 'A folder named outright is refused'
        Assert-Throws -ScriptBlock {
            & $module { Resolve-GitHubGistSource -Path 'sub*' }
        } -MessageLike "'sub``*' matches no file." -Message 'and so is a wildcard matching only a folder'
        Assert-Throws -ScriptBlock {
            & $module { Resolve-GitHubGistSource -Path '.h*' }
        } -MessageLike "'.h``*' matches no file." -Message 'and one matching only a hidden file'
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
