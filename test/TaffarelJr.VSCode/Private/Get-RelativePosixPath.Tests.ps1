#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-RelativePosixPath.ps1')

$base = Join-Path ([Path]::GetTempPath()) 'relative-path-lab'

#───────────────────────────────────────────────────────────────────────────────
# Act
$result = Get-RelativePosixPath -From (Join-Path $base 'a') -To (Join-Path $base 'b')

# Assert
Assert-Equal -Expected '../b' -Actual $result -Message 'A sibling is one level up, then across'

#───────────────────────────────────────────────────────────────────────────────
# Act
$result = Get-RelativePosixPath -From (Join-Path $base 'a') -To (Join-Path $base 'a' 'sub' 'deep')

# Assert
Assert-Equal -Expected 'sub/deep' -Actual $result `
    -Message 'A descendant is joined with forward slashes, never backslashes'

#───────────────────────────────────────────────────────────────────────────────
# Act
$result = Get-RelativePosixPath -From (Join-Path $base 'a') -To (Join-Path $base 'a')

# Assert
Assert-Equal -Expected '.' -Actual $result -Message 'The same folder is "."'

#───────────────────────────────────────────────────────────────────────────────
# Act
$result = Get-RelativePosixPath -From (Join-Path $base 'a' 'b' 'c') -To (Join-Path $base 'x')

# Assert
Assert-Equal -Expected '../../../x' -Actual $result -Message 'Each level up is its own ".."'

exit (Complete-TestRun)
