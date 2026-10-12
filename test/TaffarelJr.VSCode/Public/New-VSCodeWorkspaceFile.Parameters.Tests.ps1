#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$root = Join-Path ([Path]::GetTempPath()) "vscode-workspace-parameters-$([Guid]::NewGuid())"
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $command = Get-Command New-VSCodeWorkspaceFile
    $viaName = Join-Path $root 'via-name.code-workspace'
    $viaAlias = Join-Path $root 'via-alias.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $viaName -Folder $repo -Setting @{ 'editor.tabSize' = 2 }
    $null = New-VSCodeWorkspaceFile -Path $viaAlias -Folder $repo -Settings @{ 'editor.tabSize' = 2 }

    # Assert
    Assert-Equal -Expected @('Settings') -Actual @($command.Parameters['Setting'].Aliases) `
        -Message 'The workspace settings are -Setting, which is also called -Settings'
    Assert-Equal -Expected 2 -Actual (Read-WorkspaceFile -Path $viaName).settings.'editor.tabSize' `
        -Message 'A setting given as -Setting is written'
    Assert-Equal -Expected 2 -Actual (Read-WorkspaceFile -Path $viaAlias).settings.'editor.tabSize' `
        -Message 'and so is one given as -Settings'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
