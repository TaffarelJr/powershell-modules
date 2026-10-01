#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

function Rename-ItemName([object[]]$Item) {
    & $module {
        [CmdletBinding()]
        param($i)
        Rename-NameToken -Item $i -From 'Placeholder' -To 'Real' -Cmdlet $PSCmdlet
    } $Item
}

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a nested directory and file, both named for the token
    $nested = Join-Path $sandbox 'nested'
    New-Item -ItemType Directory -Path (Join-Path $nested 'Placeholder.Sub') | Out-Null
    [File]::WriteAllText((Join-Path $nested 'Placeholder.Sub' 'Placeholder.txt'), 'x')
    $items = @(Get-ChildItem -LiteralPath $nested -Recurse -Force)

    # Act
    $result = Rename-ItemName -Item $items

    # Assert
    Assert-Equal -Expected 2 -Actual $result.Renamed -Message 'Both the directory and the file are renamed'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $nested 'Real.Sub' 'Real.txt')) `
        -Message 'The child is renamed before its parent, so its path is never stale mid-rename'
    Assert-Equal -Expected 0 -Actual @($result.Failed).Count -Message 'A clean rename reports no failures'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rename that collides with a file already there
    $collision = Join-Path $sandbox 'collision'
    New-Item -ItemType Directory -Path $collision | Out-Null
    [File]::WriteAllText((Join-Path $collision 'Placeholder.txt'), 'x')
    [File]::WriteAllText((Join-Path $collision 'Real.txt'), 'already here')
    [File]::WriteAllText((Join-Path $collision 'OtherPlaceholder.txt'), 'x')
    $collisionItems = @(Get-ChildItem -LiteralPath $collision -Recurse -Force)

    # Act
    $collided = Rename-ItemName -Item $collisionItems

    # Assert
    Assert-Equal -Expected 1 -Actual $collided.Renamed -Message 'The non-colliding item still gets renamed'
    Assert-Equal -Expected 1 -Actual @($collided.Failed).Count `
        -Message 'and the collision is recorded as exactly one failure'
    Assert-That -Condition ($collided.Failed[0] -like "$(Join-Path $collision 'Placeholder.txt') -> Real.txt - *") `
        -Message 'naming the source, the new name, and why'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a token that appears more than once in one name, and items without it
    $repeats = Join-Path $sandbox 'repeats'
    New-Item -ItemType Directory -Path $repeats | Out-Null
    [File]::WriteAllText((Join-Path $repeats 'PlaceholderPlaceholder.txt'), 'x')
    [File]::WriteAllText((Join-Path $repeats 'keep.txt'), 'x')
    $repeatItems = @(Get-ChildItem -LiteralPath $repeats -Force)

    # Act
    $repeated = Rename-ItemName -Item $repeatItems

    # Assert
    Assert-Equal -Expected 1 -Actual $repeated.Renamed -Message 'Only the item whose name has the token is renamed'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $repeats 'RealReal.txt')) `
        -Message 'and every occurrence in its name is replaced'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - nothing to rename
    $nothing = Rename-ItemName -Item @()

    # Assert
    Assert-Equal -Expected 0 -Actual $nothing.Renamed -Message 'No items is no work'
    Assert-Equal -Expected 0 -Actual @($nothing.Failed).Count -Message 'and no failures'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
