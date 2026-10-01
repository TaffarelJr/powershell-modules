#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files, a folder, a hidden file, and something one level further down
    [File]::WriteAllText((Join-Path $sandbox 'a.txt'), 'x')
    New-Item -ItemType Directory -Path (Join-Path $sandbox 'sub') | Out-Null
    [File]::WriteAllText((Join-Path $sandbox 'sub' 'deeper.txt'), 'x')
    $hidden = Join-Path $sandbox '.hidden'
    [File]::WriteAllText($hidden, 'x')
    (Get-Item -LiteralPath $hidden -Force).Attributes = 'Hidden'

    # Act
    $names = @(& $module { param($p) Get-DirectoryEntry -Path $p } $sandbox | ForEach-Object Name | Sort-Object)

    # Assert
    Assert-Equal -Expected @('.hidden', 'a.txt', 'sub') -Actual $names `
        -Message 'Everything directly inside, hidden items included, and nothing further down'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $empty = Join-Path $sandbox 'empty'
    New-Item -ItemType Directory -Path $empty | Out-Null

    # Act
    $none = @(& $module { param($p) Get-DirectoryEntry -Path $p } $empty)

    # Assert
    Assert-Equal -Expected 0 -Actual $none.Count -Message 'An empty folder has nothing in it'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is not there
    Assert-Throws -ScriptBlock { & $module { param($p) Get-DirectoryEntry -Path $p } (Join-Path $sandbox 'nope') } `
        -MessageLike '*nope*' `
        -Message 'A folder that cannot be listed throws, naming it'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
