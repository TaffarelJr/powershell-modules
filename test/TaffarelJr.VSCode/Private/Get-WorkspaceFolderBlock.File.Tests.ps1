#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-NativePath.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-RelativePosixPath.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-JsonLiteral.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-WorkspaceFolderBlock.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
$file = Join-Path $repo 'notes.txt'
[File]::WriteAllText($file, 'x')
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a "folder" that is a file
    $specs = @([PSCustomObject]@{ Path = $file; Name = $null; Comment = $null })

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-WorkspaceFolderBlock -Directory $repo -Folder $specs
    } -MessageLike '*A workspace folder must be a folder, and this is not:*notes.txt*' `
        -Message 'A file given as a workspace folder is refused, naming it'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
