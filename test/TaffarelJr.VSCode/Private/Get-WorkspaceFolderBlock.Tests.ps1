#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-NativePath.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-RelativePosixPath.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-JsonLiteral.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-WorkspaceFolderBlock.ps1')

function New-Spec([string]$Path, [string]$Name, [string]$Comment) {
    return [PSCustomObject]@{
        Path    = $Path
        Name    = $Name
        Comment = $Comment
    }
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
$lib = Join-Path $root 'lib'
New-Item -ItemType Directory -Path $repo, $lib | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @((New-Spec -Path $repo), (New-Spec -Path $lib))

    # Act
    $lines = Get-WorkspaceFolderBlock -Directory $repo -Folder $specs

    # Assert
    $expected = @(
        '  "folders": ['
        '    { "path": "." },'
        '    { "path": "../lib" }'
        '  ]'
    )
    Assert-Equal -Expected $expected -Actual $lines -Message 'Entries are relative to the directory, with a comma on every one but the last'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @(New-Spec -Path $repo -Name 'the "main" one' -Comment "line one`nline two")

    # Act
    $lines = Get-WorkspaceFolderBlock -Directory $repo -Folder $specs

    # Assert
    $expected = @(
        '  "folders": ['
        '    // line one'
        '    // line two'
        '    { "name": "the \"main\" one", "path": "." }'
        '  ]'
    )
    Assert-Equal -Expected $expected -Actual $lines -Message 'A comment is one // line per line of text, and a name is escaped'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @(New-Spec -Path $lib)

    # Act
    $lines = Get-WorkspaceFolderBlock -Directory $repo -Folder $specs

    # Assert
    Assert-Equal -Expected '    { "path": "../lib" }' -Actual $lines[1] -Message 'A single entry has no trailing comma'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @(New-Spec -Path (Join-Path $root 'not-there'))

    # Act / Assert
    Assert-Throws -ScriptBlock { Get-WorkspaceFolderBlock -Directory $repo -Folder $specs } -Message 'A folder that does not exist throws'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
