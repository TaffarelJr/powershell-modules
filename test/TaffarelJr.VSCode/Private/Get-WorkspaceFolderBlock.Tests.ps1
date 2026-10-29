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

function New-Spec {
    [CmdletBinding()]
    param(
        [string]$Path,

        [object]$Name,

        [string]$Comment
    )

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
$separator = [Path]::DirectorySeparatorChar
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @((New-Spec -Path $repo), (New-Spec -Path $lib))

    # Act
    $lines = @(Get-WorkspaceFolderBlock -Directory $repo -Folder $specs)

    # Assert
    $expected = @(
        '  "folders": ['
        '    { "path": "." },'
        '    { "path": "../lib" }'
        '  ]'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'Entries are relative to the directory, with a comma on every one but the last'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @(New-Spec -Path $repo -Name 'the "main" one' -Comment "line one`rline two`nline three")

    # Act
    $lines = @(Get-WorkspaceFolderBlock -Directory $repo -Folder $specs)

    # Assert
    $expected = @(
        '  "folders": ['
        '    // line one'
        '    // line two'
        '    // line three'
        '    { "name": "the \"main\" one", "path": "." }'
        '  ]'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'A comment is one // line per line of text, whatever its line ending, and a name is escaped'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $specs = @(New-Spec -Path $lib)

    # Act
    $lines = @(Get-WorkspaceFolderBlock -Directory $repo -Folder $specs)

    # Assert
    Assert-Equal -Expected '    { "path": "../lib" }' -Actual $lines[1] -Message 'A single entry has no trailing comma'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a name given as a number, where VS Code expects a string
    $specs = @(New-Spec -Path $lib -Name 7)

    # Act
    $lines = @(Get-WorkspaceFolderBlock -Directory $repo -Folder $specs)

    # Assert
    Assert-Equal -Expected '    { "name": "7", "path": "../lib" }' -Actual $lines[1] `
        -Message 'A name that is not a string is written as one'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - names that are falsy but given, and an empty one
    $zero = @(New-Spec -Path $lib -Name 0)
    $empty = @(New-Spec -Path $lib -Name '')

    # Act
    $zeroLines = @(Get-WorkspaceFolderBlock -Directory $repo -Folder $zero)
    $emptyLines = @(Get-WorkspaceFolderBlock -Directory $repo -Folder $empty)

    # Assert
    Assert-Equal -Expected '    { "name": "0", "path": "../lib" }' -Actual $zeroLines[1] `
        -Message 'A name of 0 is written, not dropped'
    Assert-Equal -Expected '    { "path": "../lib" }' -Actual $emptyLines[1] -Message 'An empty name is left out'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder given with a trailing separator
    $specs = @(New-Spec -Path "$lib$separator")

    # Act
    $lines = @(Get-WorkspaceFolderBlock -Directory $repo -Folder $specs)

    # Assert
    Assert-Equal -Expected '    { "path": "../lib" }' -Actual $lines[1] `
        -Message 'A trailing separator is not carried into the entry'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - one folder given twice, once with a trailing separator
    $specs = @((New-Spec -Path $lib), (New-Spec -Path "$lib$separator"))

    # Act
    $pattern = "*The same workspace folder is given twice:*$([WildcardPattern]::Escape($lib))*"

    # Assert
    Assert-Throws -ScriptBlock {
        Get-WorkspaceFolderBlock -Directory $repo -Folder $specs
    } -MessageLike $pattern -Message 'A folder given twice is refused, naming it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $missing = Join-Path $root 'not-there'
    $specs = @(New-Spec -Path $missing)

    # Act
    $pattern = "*A workspace folder does not exist: $([WildcardPattern]::Escape($missing))*"

    # Assert
    Assert-Throws -ScriptBlock {
        Get-WorkspaceFolderBlock -Directory $repo -Folder $specs
    } -MessageLike $pattern -Message 'A folder that does not exist is refused with the module''s own message'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
