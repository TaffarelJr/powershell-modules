#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$functions = @(
    'Assert-JsonValue', 'Get-NativePath', 'Get-RelativePosixPath', 'ConvertTo-JsonLiteral'
    'Get-FolderSettingsBody', 'Get-WorkspaceFolderBlock', 'Get-WorkspaceSettingBlock'
    'Get-WorkspaceExtensionBlock', 'Get-WorkspaceContent'
)
foreach ($name in $functions) {
    . (Join-Path $repoRoot "src/TaffarelJr.VSCode/Private/$name.ps1")
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a comment of several lines, whose later lines would otherwise
    # be loose text in the middle of the file
    $folder = @([PSCustomObject]@{ Path = $repo; Name = $null; Comment = $null })

    # Act
    $lines = @(Get-WorkspaceContent -Directory $repo -Folder $folder -Comment "first`r`nsecond`nthird", "fourth`rfifth")

    # Assert
    Assert-Equal `
        -Expected @('{', '  // first', '  // second', '  // third', '  // fourth', '  // fifth', '  "folders": [') `
        -Actual $lines[0..6] `
        -Message 'Every line of a comment is a comment of its own, whatever its line ending'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
