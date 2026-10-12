#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-NativePath.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Get-NativePath -Path $repo

    # Assert
    Assert-Equal -Expected $repo -Actual $result -Message 'An absolute path resolves to itself'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative path, from a different current location than the
    # process's own
    Push-Location $root

    # Act
    $result = Get-NativePath -Path 'repo'
    Pop-Location

    # Assert
    Assert-Equal -Expected $repo -Actual $result -Message 'A relative path resolves against the current location'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a path reached through a mapped PSDrive
    $null = New-PSDrive -Name VscNativeLab -PSProvider FileSystem -Root $root -Scope Global

    # Act
    $result = Get-NativePath -Path 'VscNativeLab:/repo'
    Remove-PSDrive -Name VscNativeLab

    # Assert
    Assert-Equal -Expected $repo -Actual $result -Message 'A PSDrive path resolves to the real filesystem path'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-NativePath -Path (Join-Path $root 'not-there')
    } -MessageLike '*Cannot find path*not-there*' -Message 'A path that does not exist throws, naming it'
}
finally {
    Remove-PSDrive -Name VscNativeLab -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
