#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Find-TestFile.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $root 'Sub') -Force | Out-Null
'' | Set-Content -LiteralPath (Join-Path $root 'A.Tests.ps1')
'' | Set-Content -LiteralPath (Join-Path $root 'Sub\B.Tests.ps1')
'' | Set-Content -LiteralPath (Join-Path $root 'NotATest.ps1')

# Act
$files = Find-TestFile -Path $root

# Assert
Assert-Equal -Expected 2 -Actual $files.Count -Message 'Finds every *.Tests.ps1 recursively, ignoring non-test files'
Assert-Equal -Expected 'A.Tests.ps1' -Actual $files[0].Name -Message 'Results are sorted by full path'
Assert-Equal -Expected 'B.Tests.ps1' -Actual $files[1].Name -Message 'A nested file sorts after its parent-level sibling'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Filter narrows by file name
$filtered = Find-TestFile -Path $root -Filter 'A'

# Assert
Assert-Equal -Expected 1 -Actual $filtered.Count -Message '-Filter narrows to matching file names'
Assert-Equal -Expected 'A.Tests.ps1' -Actual $filtered[0].Name -Message 'The filtered result is the expected file'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty folder
$emptyRoot = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
$empty = Find-TestFile -Path $emptyRoot

# Assert
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'An empty folder returns zero files, never $null'
Assert-That -Condition ($empty -is [array]) -Message 'The empty result is still an array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several folders searched in one call
$second = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $second -Force | Out-Null
'' | Set-Content -LiteralPath (Join-Path $second 'C.Tests.ps1')
$combined = Find-TestFile -Path @($root, $second)

# Assert
Assert-Equal -Expected 3 -Actual $combined.Count -Message 'Every given folder is searched, results combined'
Assert-That -Condition ($combined.Name -contains 'C.Tests.ps1') -Message 'A file from the second folder is included too'

# Cleanup
Remove-Item -LiteralPath $root, $emptyRoot, $second -Recurse -Force

exit (Complete-TestRun)
