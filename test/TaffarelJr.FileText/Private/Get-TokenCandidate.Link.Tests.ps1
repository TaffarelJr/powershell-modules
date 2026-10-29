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
    $outside = Join-Path $sandbox 'outside'
    New-Item -ItemType Directory -Path $outside | Out-Null
    [File]::WriteAllText((Join-Path $outside 'beyond.txt'), 'x')
    $tree = Join-Path $sandbox 'tree'
    New-Item -ItemType Directory -Path $tree | Out-Null
    $link = New-TestLink -Path (Join-Path $tree 'linked') -Target $outside
    if (-not $link) {
        Remove-FileTextSandbox -Path $sandbox
        exit (Skip-TestRun -Reason 'this machine does not allow symbolic links')
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    [File]::WriteAllText((Join-Path $tree 'own.txt'), 'x')
    Install-DirectoryListingStub -Module $module

    # Act
    $result = & $module { param($p) Get-TokenCandidate -Path $p -Exclude @() } $tree
    $visited = @(Get-VisitedFolder -Module $module)

    # Assert
    Assert-Equal -Expected @('linked', 'own.txt') -Actual @($result.Item | ForEach-Object Name | Sort-Object) `
        -Message 'A link to a folder is a candidate itself - its name can be renamed - but what it points at is not'
    Assert-Equal -Expected @($tree) -Actual $visited `
        -Message 'and the walk never goes into it, so it cannot leave the tree or go round in a circle'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
