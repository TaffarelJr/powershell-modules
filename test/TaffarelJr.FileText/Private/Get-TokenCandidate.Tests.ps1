#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Private/Get-TokenCandidate.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tree with an excluded subdirectory
    New-Item -ItemType Directory -Path (Join-Path $root 'bin') | Out-Null
    [File]::WriteAllText((Join-Path $root 'bin' 'inside.txt'), 'x')
    [File]::WriteAllText((Join-Path $root 'outside.txt'), 'x')

    # Act
    $result = Get-TokenCandidate -Path $root -Exclude @('bin')

    # Assert
    $names = @($result.Item | ForEach-Object { $_.Name })
    Assert-That -Condition ($names -contains 'outside.txt') -Message 'An item outside the excluded directory is included'
    Assert-That -Condition ($names -notcontains 'inside.txt') -Message 'An item under the excluded directory is not included'
    Assert-Equal -Expected 0 -Actual $result.Warning.Count -Message 'A normal, fully-readable tree reports no warnings'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - exclusion matches by relative path, not absolute -
    # a tree that happens to live under a folder sharing the excluded name
    # must not exclude its own entire contents
    $nestedRoot = Join-Path $root 'bin' 'nested-root'
    New-Item -ItemType Directory -Path $nestedRoot | Out-Null
    [File]::WriteAllText((Join-Path $nestedRoot 'file.txt'), 'x')
    $nestedResult = Get-TokenCandidate -Path $nestedRoot -Exclude @('bin')
    $nestedNames = @($nestedResult.Item | ForEach-Object { $_.Name })
    Assert-That -Condition ($nestedNames -contains 'file.txt') -Message 'A root living under a folder sharing the excluded name still finds its own contents'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
