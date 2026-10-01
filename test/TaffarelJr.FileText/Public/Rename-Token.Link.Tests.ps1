#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    $outsideFile = Join-Path $sandbox 'outside.txt'
    [File]::WriteAllText($outsideFile, 'Placeholder lives outside')
    $outsideFolder = Join-Path $sandbox 'outside-folder'
    New-Item -ItemType Directory -Path $outsideFolder | Out-Null
    [File]::WriteAllText((Join-Path $outsideFolder 'Placeholder.txt'), 'Placeholder')

    $tree = Join-Path $sandbox 'tree'
    New-Item -ItemType Directory -Path $tree | Out-Null
    $fileLink = New-TestLink -Path (Join-Path $tree 'Placeholder.link') -Target $outsideFile
    if (-not $fileLink) {
        Remove-FileTextSandbox -Path $sandbox
        exit (Skip-TestRun -Reason 'this machine does not allow symbolic links')
    }

    $null = New-TestLink -Path (Join-Path $tree 'PlaceholderFolder') -Target $outsideFolder
    $null = New-TestLink -Path (Join-Path $tree 'broken.txt') -Target (Join-Path $sandbox 'does-not-exist.txt')
    [File]::WriteAllText((Join-Path $tree 'own.txt'), 'Placeholder')

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Rename-Token -Path $tree -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 'Placeholder lives outside' -Actual ([File]::ReadAllText($outsideFile)) `
        -Message 'A file outside the tree is not rewritten through a link to it'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $outsideFolder 'Placeholder.txt')) `
        -Message 'and nothing inside a folder outside the tree is renamed through a link to it'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText((Join-Path $outsideFolder 'Placeholder.txt'))) `
        -Message 'or rewritten'
    Assert-Equal -Expected 1 -Actual $result.FilesEdited -Message 'Only the tree''s own file is edited'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $tree 'Real.link') -PathType Leaf) `
        -Message 'The link to a file is renamed, being a name in the tree'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $tree 'RealFolder')) `
        -Message 'and so is the link to a folder'
    Assert-Equal -Expected 2 -Actual $result.PathsRenamed `
        -Message 'Both links are counted, and nothing else, since the tree''s own file has no token in its name'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
