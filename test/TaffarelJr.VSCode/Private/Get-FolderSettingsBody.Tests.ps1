#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-FolderSettingsBody.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

function New-SettingsFolder([string]$Name, [string]$Content) {
    $folder = Join-Path $root $Name
    New-Item -ItemType Directory -Path (Join-Path $folder '.vscode') | Out-Null
    [File]::WriteAllText((Join-Path $folder '.vscode' 'settings.json'), $Content)
    return $folder
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with no .vscode at all
    $bare = Join-Path $root 'bare'
    New-Item -ItemType Directory -Path $bare | Out-Null

    # Act
    $lines = Get-FolderSettingsBody -FolderPath $bare

    # Assert
    Assert-That -Condition ($lines -is [array]) -Message 'No settings file still returns an array'
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'No settings file means no lines'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $folder = New-SettingsFolder -Name 'plain' -Content "{`n  `"editor.formatOnSave`": true,`n  `"editor.tabSize`": 2`n}"

    # Act
    $lines = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected @('    "editor.formatOnSave": true,', '    "editor.tabSize": 2') -Actual $lines -Message 'The body is returned one level deeper, braces left out'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a leading note, an inline note, and a nested object
    $content = "// why these are set`n{`n  // keep this`n  `"files.exclude`": {`n    `"**/bin`": true`n  }`n}"
    $folder = New-SettingsFolder -Name 'jsonc' -Content $content

    # Act
    $warnings = Get-WarningText -ScriptBlock { Get-FolderSettingsBody -FolderPath $folder }
    $lines = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected 0 -Actual $warnings.Count -Message 'A legal JSONC file does not warn'
    Assert-Equal -Expected @('    // keep this', '    "files.exclude": {', '      "**/bin": true', '    }') -Actual $lines -Message 'Comments and nesting survive, and the leading note outside the braces is left behind'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - tab-indented
    $folder = New-SettingsFolder -Name 'tabs' -Content "{`r`n`t`"editor.formatOnSave`": true`r`n}"

    # Act
    $lines = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected @('    "editor.formatOnSave": true') -Actual $lines -Message 'A tab-indented file loses its tabs'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - CRLF line endings
    $folder = New-SettingsFolder -Name 'crlf' -Content "{`r`n  `"a`": 1,`r`n  `"b`": 2`r`n}"

    # Act
    $lines = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-That -Condition (-not ($lines -match "`r")) -Message 'No carriage return is carried into the lines'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an object with nothing in it
    $folder = New-SettingsFolder -Name 'empty' -Content "{`n}"

    # Act
    $lines = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'An empty object has no lines'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - no JSON object at all
    $folder = New-SettingsFolder -Name 'notjson' -Content 'just a note, no braces'

    # Act
    $warnings = Get-WarningText -ScriptBlock { Get-FolderSettingsBody -FolderPath $folder }
    $lines = Get-FolderSettingsBody -FolderPath $folder 3>$null

    # Assert
    Assert-Equal -Expected 1 -Actual $warnings.Count -Message 'A file with no object warns once'
    Assert-That -Condition ($warnings[0] -like '*settings.json*') -Message 'The warning names the file'
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A file with no object contributes no lines'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
