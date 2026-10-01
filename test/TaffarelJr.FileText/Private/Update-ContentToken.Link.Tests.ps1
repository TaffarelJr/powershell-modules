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
    $outside = Join-Path $sandbox 'outside.txt'
    [File]::WriteAllText($outside, 'Placeholder lives outside')
    $tree = Join-Path $sandbox 'tree'
    New-Item -ItemType Directory -Path $tree | Out-Null
    $link = New-TestLink -Path (Join-Path $tree 'link.txt') -Target $outside
    if (-not $link) {
        Remove-FileTextSandbox -Path $sandbox
        exit (Skip-TestRun -Reason 'this machine does not allow symbolic links')
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a link to a file outside the tree, and a file of the tree's own
    $own = Join-Path $tree 'own.txt'
    [File]::WriteAllText($own, 'Placeholder')
    $items = @(Get-ChildItem -LiteralPath $tree -File)

    # Act
    $result = & $module {
        [CmdletBinding()]
        param($i)
        Update-ContentToken -Item $i -From 'Placeholder' -To 'Real' -SkipExtension @() -Cmdlet $PSCmdlet
    } $items

    # Assert
    Assert-Equal -Expected 1 -Actual $result.Edited -Message 'Only the file that is really in the tree is edited'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText($own)) -Message 'and it is the tree''s own file'
    Assert-Equal -Expected 'Placeholder lives outside' -Actual ([File]::ReadAllText($outside)) `
        -Message 'What the link points at is never written through it'
    Assert-Equal -Expected 0 -Actual @($result.Failed).Count -Message 'and stepping over a link is not a failure'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
