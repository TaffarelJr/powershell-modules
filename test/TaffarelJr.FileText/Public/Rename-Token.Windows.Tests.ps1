#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'junctions and reserved device names are Windows file system matters')
}

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - junctions, which need no privilege: one back to the tree, one
    # to a folder outside it, and one to a folder of the tree's own whose name
    # holds the token
    $outside = Join-Path $sandbox 'outside'
    New-Item -ItemType Directory -Path $outside | Out-Null
    $outsideFile = Join-Path $outside 'Placeholder.txt'
    [File]::WriteAllText($outsideFile, 'Placeholder')
    $tree = Join-Path $sandbox 'tree'
    $inner = Join-Path $tree 'PlaceholderDir'
    New-Item -ItemType Directory -Path $inner | Out-Null
    [File]::WriteAllText((Join-Path $tree 'own.txt'), 'Placeholder')
    $null = New-Item -ItemType Junction -Path (Join-Path $tree 'loop') -Target $tree
    $null = New-Item -ItemType Junction -Path (Join-Path $tree 'PlaceholderOut') -Target $outside
    $shortcut = Join-Path $tree 'shortcut'
    $null = New-Item -ItemType Junction -Path $shortcut -Target $inner

    # Act
    $result = Rename-Token -Path $tree -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal `
        -Expected 1 `
        -Actual $result.FilesEdited `
        -Message 'Only the tree''s own file is edited: no junction is entered, so no loop and no leaving'
    Assert-Equal `
        -Expected 'Placeholder' `
        -Actual ([File]::ReadAllText($outsideFile)) `
        -Message 'A file outside the tree is not rewritten through a junction to it'
    Assert-That -Condition (Test-Path -LiteralPath $outsideFile) -Message 'or renamed'
    Assert-That `
        -Condition (Test-Path -LiteralPath (Join-Path $tree 'RealOut')) `
        -Message 'A junction''s own name is renamed, being a name in the tree'
    Assert-Equal -Expected 2 -Actual $result.PathsRenamed -Message 'and is counted with the tree''s own folder'
    Assert-Equal `
        -Expected @("Link target still says 'Placeholder': $shortcut -> $inner") `
        -Actual @($result.Warning) `
        -Message 'A link whose target holds the token is named, since the rename leaves it pointing at the old name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a name that would become a device name
    $reserved = Join-Path $sandbox 'reserved'
    New-Item -ItemType Directory -Path $reserved | Out-Null
    $reservedFile = Join-Path $reserved 'Placeholder.txt'
    [File]::WriteAllText($reservedFile, 'Placeholder')

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Rename-Token -Path $reserved -From 'Placeholder' -To 'CON' } `
        -MessageLike "Cannot rename 'Placeholder' to 'CON': 1 of the new names would be unusable on Windows*",
        "*$reservedFile -> CON.txt - older Windows and many Windows tools treat it as a device.*" `
        -Message 'A new name Windows tools treat as a device is refused, naming the item'
    Assert-Equal `
        -Expected 'Placeholder' `
        -Actual ([File]::ReadAllText($reservedFile)) `
        -Message 'before the content pass has changed anything'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a name that would end with a dot
    $dotted = Join-Path $sandbox 'dotted'
    $dottedFolder = Join-Path $dotted 'Placeholder'
    New-Item -ItemType Directory -Path $dottedFolder | Out-Null

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Rename-Token -Path $dotted -From 'Placeholder' -To 'Real.' } `
        -MessageLike "*$dottedFolder -> Real. - Windows drops a trailing dot or space*" `
        -Message 'A new name ending in a dot is refused, since Windows would quietly drop it'
    Assert-That -Condition (Test-Path -LiteralPath $dottedFolder) -Message 'and nothing is renamed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same replacement, landing in the middle of a name
    $middle = Join-Path $sandbox 'middle'
    New-Item -ItemType Directory -Path (Join-Path $middle 'PlaceholderApp') | Out-Null

    # Act
    $middleResult = Rename-Token -Path $middle -From 'Placeholder' -To 'Real.'

    # Assert
    Assert-Equal `
        -Expected 1 `
        -Actual $middleResult.PathsRenamed `
        -Message 'A replacement ending in a dot is fine where the name goes on after it'
    Assert-That `
        -Condition (Test-Path -LiteralPath (Join-Path $middle 'Real.App')) `
        -Message 'and the name is exactly as asked'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
