#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru

$root = Join-Path ([System.IO.Path]::GetTempPath()) "git-root-$([Guid]::NewGuid())"
$sub = Join-Path $root 'sub'
$convert = {
    param($Path, $Root, $RepoPath)
    ConvertTo-GitFullPath -Path $Path -Root $Root -RepoPath $RepoPath
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$bare = & $module $convert 'src\x.txt' $root $sub
$dotted = & $module $convert './x.txt' $root $sub
$climbing = & $module $convert '..\y.txt' $root $sub
$inner = & $module $convert 'src/../z.txt' $root $sub

# Assert
Assert-Equal -Expected (Join-Path $root 'src' 'x.txt') -Actual $bare `
    -Message 'A bare relative path is relative to the root, with the platform''s separators'
Assert-Equal -Expected (Join-Path $sub 'x.txt') -Actual $dotted `
    -Message 'A path that starts with . is relative to -RepoPath'
Assert-Equal -Expected (Join-Path $root 'y.txt') -Actual $climbing -Message 'and so is one that starts with ..'
Assert-Equal -Expected (Join-Path $root 'z.txt') -Actual $inner -Message 'An inner .. segment is resolved'

#───────────────────────────────────────────────────────────────────────────────
# Act
$full = Join-Path $root 'elsewhere' 'w.txt'
$absolute = & $module $convert $full $root $sub

# Assert
Assert-Equal -Expected $full -Actual $absolute -Message 'An absolute path is used as it is'

exit (Complete-TestRun)
