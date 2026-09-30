#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Get-TestDisplayName.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a test folder, and files in and directly under it
$testRoot = Join-Path ([Path]::GetTempPath()) 'repo' 'test'
$nestedFile = Join-Path $testRoot 'Module' 'Public' 'Write-Success.Tests.ps1'
$topFile = Join-Path $testRoot 'Top.Tests.ps1'

# Act
$name = Get-TestDisplayName -TestRoot $testRoot -File $nestedFile
$rootName = Get-TestDisplayName -TestRoot $testRoot -File $topFile

# Assert
Assert-Equal -Expected 'Module/Public/Write-Success' -Actual $name `
    -Message 'Strips the suffix and converts to forward slashes'
Assert-Equal -Expected 'Top' -Actual $rootName -Message 'A file directly under the root has no leading slash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder whose name merely starts with two dots is still inside
$dotted = Join-Path $testRoot '..hidden' 'X.Tests.ps1'

# Act
$dottedName = Get-TestDisplayName -TestRoot $testRoot -File $dotted

# Assert
Assert-Equal -Expected '..hidden/X' -Actual $dottedName `
    -Message 'A folder named like ..hidden is not mistaken for climbing out'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder named two dots and a zero-width joiner, which a comparison
# that ignores such characters would read as climbing out
$joiner = [string][char]0x200D
$joined = Join-Path $testRoot "..$joiner" 'X.Tests.ps1'

# Act
$joinedName = Get-TestDisplayName -TestRoot $testRoot -File $joined

# Assert
Assert-Equal -Expected "..$joiner/X" -Actual $joinedName `
    -Message 'A folder named two dots and a zero-width joiner is not mistaken for climbing out'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file that is not under the test folder
$elsewhere = Join-Path ([Path]::GetTempPath()) 'other' 'X.Tests.ps1'

# Assert
Assert-Throws -ScriptBlock {
    Get-TestDisplayName -TestRoot $testRoot -File $elsewhere
} -MessageLike '*other*not under -TestRoot*' `
    -Message 'A file outside the root throws, naming it, instead of getting a name that climbs out with ..'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the folder itself, and its parent
Assert-Throws -ScriptBlock {
    Get-TestDisplayName -TestRoot $testRoot -File (Split-Path -Parent $testRoot)
} -MessageLike '*not under -TestRoot*' -Message 'The root''s own parent is not under it'

exit (Complete-TestRun)
