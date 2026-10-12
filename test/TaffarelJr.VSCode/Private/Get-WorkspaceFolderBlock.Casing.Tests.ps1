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

# Only Windows' file system ignores case, so only there do lib and LIB name
# the same folder.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'folder names differing only in case are one folder on Windows only')
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$lib = Join-Path $root 'lib'
New-Item -ItemType Directory -Path $lib | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @(
        [PSCustomObject]@{
            Path    = $lib
            Name    = $null
            Comment = $null
        }
        [PSCustomObject]@{
            Path    = Join-Path $root 'LIB'
            Name    = $null
            Comment = $null
        }
    )

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-WorkspaceFolderBlock -Directory $root -Folder $specs
    } -MessageLike '*The same workspace folder is given twice:*LIB*' `
        -Message 'A folder given again in other casing is refused'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
