#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru

$temp = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')

#───────────────────────────────────────────────────────────────────────────────
# Act
$bare = @(& $module { Resolve-GitPath -Path 'src\x.txt' })

# Assert
Assert-Equal -Expected 0 -Actual $bare.Count `
    -Message 'A bare relative path is left to the repository root: nothing comes back'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$full = Join-Path $temp 'repo' '..' 'x.txt'

# Act
$absolute = & $module { param($p) Resolve-GitPath -Path $p } $full

# Assert
Assert-Equal -Expected ($full -replace '\\', '/') -Actual $absolute `
    -Message 'An absolute path comes back as it is, with forward slashes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Push-Location -LiteralPath $temp

# Act
try {
    $dotted = & $module { Resolve-GitPath -Path '.\sub\..\x.txt' }
    $byRelativeRepoPath = & $module { Resolve-GitPath -Path '..\x.txt' -RepoPath 'repo' }
    $driveless = & $module { Resolve-GitPath -Path '\x.txt' }
}
finally {
    Pop-Location
}

# Assert
Assert-Equal -Expected (Join-Path $temp 'x.txt') -Actual $dotted `
    -Message 'A path starting with a dot is made absolute against the current location, and normalized'
Assert-Equal -Expected (Join-Path $temp 'x.txt') -Actual $byRelativeRepoPath `
    -Message 'A relative -RepoPath is itself resolved against the current location first'
Assert-Equal -Expected ([System.IO.Path]::GetFullPath('/x.txt', $temp)) -Actual $driveless `
    -Message 'A rooted path with no drive is resolved against the current location, never read as a bare path'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the path as the PSPath property of Get-Item output holds it
$plain = Join-Path $temp 'repo' 'x.txt'
$pspath = "Microsoft.PowerShell.Core\FileSystem::$plain"
$short = "FileSystem::$plain"

# Act
$fromPsPath = & $module { param($p) Resolve-GitPath -Path $p } $pspath
$fromShortForm = & $module { param($p) Resolve-GitPath -Path $p } $short

# Assert
Assert-Equal -Expected ($plain -replace '\\', '/') -Actual $fromPsPath `
    -Message 'A provider-qualified path is read as the path after the provider'
Assert-Equal -Expected ($plain -replace '\\', '/') -Actual $fromShortForm `
    -Message 'and so is one that leaves out the provider''s module'

exit (Complete-TestRun)
