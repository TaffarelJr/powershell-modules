#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Private/Rename-NameToken.ps1')

# --- a nested directory and file are both renamed, child before parent ---
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $dirPath = Join-Path $root 'Placeholder.Sub'
    New-Item -ItemType Directory -Path $dirPath | Out-Null
    [File]::WriteAllText((Join-Path $dirPath 'Placeholder.txt'), 'x')
    $items = @(Get-ChildItem -LiteralPath $root -Recurse -Force)

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Rename-NameToken -Item $items -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 2 -Actual $result.Renamed -Message 'Both the directory and the file are renamed'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $root 'Real.Sub' 'Real.txt')) -Message 'The child is renamed before its parent, so its path is never stale mid-rename'
    Assert-Equal -Expected 0 -Actual $result.Failed.Count -Message 'A clean rename reports no failures'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- a rename collision is recorded, naming both paths, without stopping the pass ---
$root2 = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root2 | Out-Null
try {
    [File]::WriteAllText((Join-Path $root2 'Placeholder.txt'), 'x')
    [File]::WriteAllText((Join-Path $root2 'Real.txt'), 'already here')
    [File]::WriteAllText((Join-Path $root2 'OtherPlaceholder.txt'), 'x')
    $items = @(Get-ChildItem -LiteralPath $root2 -Recurse -Force)

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Rename-NameToken -Item $items -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 1 -Actual $result.Renamed -Message 'The non-colliding item still gets renamed'
    Assert-Equal -Expected 1 -Actual $result.Failed.Count -Message 'The collision is recorded as exactly one failure'
    Assert-That -Condition ($result.Failed[0] -like '*Placeholder.txt*') -Message 'The failure names the source'
    Assert-That -Condition ($result.Failed[0] -like '*Real.txt*') -Message 'The failure names the target it collided with'
}
finally {
    Remove-Item -LiteralPath $root2 -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
