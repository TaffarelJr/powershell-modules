#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-JsonLiteral.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-FolderSettingsBody.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-WorkspaceSettingBlock.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$mirrored = Join-Path $root 'mirrored'
$empty = Join-Path $root 'empty'
New-Item -ItemType Directory -Path (Join-Path $mirrored '.vscode'), $empty | Out-Null
[File]::WriteAllText((Join-Path $mirrored '.vscode' 'settings.json'), "{`n  `"editor.tabSize`": 2`n}")
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = Get-WorkspaceSettingBlock

    # Assert
    Assert-That -Condition ($lines -is [array]) -Message 'Nothing to write still returns an array'
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'No settings and nothing mirrored writes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = Get-WorkspaceSettingBlock -MirrorFolderPath $empty

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A mirrored folder with no settings file writes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $settings = [ordered]@{
        'editor.rulers'       = @(80, 120)
        'editor.formatOnSave' = $true
    }

    # Act
    $lines = Get-WorkspaceSettingBlock -Settings $settings

    # Assert
    $expected = @(
        '  "settings": {'
        '    "editor.rulers": [80,120],'
        '    "editor.formatOnSave": true'
        '  }'
    )
    Assert-Equal -Expected $expected -Actual $lines -Message 'Each setting is one line, with a comma on every one but the last'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = Get-WorkspaceSettingBlock -MirrorFolderPath $mirrored

    # Assert
    $expected = @(
        '  "settings": {'
        '    // Mirrored from .vscode/settings.json, because VS Code ignores'
        '    // window-scoped folder settings in a multi-root workspace.'
        '    "editor.tabSize": 2'
        '  }'
    )
    Assert-Equal -Expected $expected -Actual $lines -Message 'Mirrored settings alone follow an explanatory comment'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = Get-WorkspaceSettingBlock -Settings ([ordered]@{ 'files.eol' = "`n" }) -MirrorFolderPath $mirrored

    # Assert
    $expected = @(
        '  "settings": {'
        '    "files.eol": "\n",'
        ''
        '    // Mirrored from .vscode/settings.json, because VS Code ignores'
        '    // window-scoped folder settings in a multi-root workspace.'
        '    "editor.tabSize": 2'
        '  }'
    )
    Assert-Equal -Expected $expected -Actual $lines -Message 'The last explicit setting gets a comma, and a blank line sets the mirrored ones apart'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
