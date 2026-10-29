#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Assert-JsonValue.ps1')
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
    $lines = @(Get-WorkspaceSettingBlock)
    $bare = Get-WorkspaceSettingBlock

    # Assert
    Assert-That -Condition ($null -eq $bare) -Message 'Nothing to write returns nothing at all, not an empty array'
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'No settings and nothing mirrored writes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = @(Get-WorkspaceSettingBlock -MirrorFolderPath $empty)

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A mirrored folder with no settings file writes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a setting with no name
    Assert-Throws -ScriptBlock { Get-WorkspaceSettingBlock -Settings @{ '' = 'x' } } `
        -MessageLike "*-Setting has a setting with a blank name*" `
        -Message 'A setting with an empty name is refused with a message of its own'
    Assert-Throws -ScriptBlock { Get-WorkspaceSettingBlock -Settings @{ '  ' = 'x' } } `
        -MessageLike "*-Setting has a setting with a blank name*" `
        -Message 'and so is one named with spaces'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $settings = [ordered]@{
        'editor.rulers'       = @(80, 120)
        'editor.formatOnSave' = $true
    }

    # Act
    $lines = @(Get-WorkspaceSettingBlock -Settings $settings)

    # Assert
    $expected = @(
        '  "settings": {'
        '    "editor.rulers": [80,120],'
        '    "editor.formatOnSave": true'
        '  }'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'Each setting is one line, with a comma on every one but the last'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = @(Get-WorkspaceSettingBlock -MirrorFolderPath $mirrored)

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
    $lines = @(Get-WorkspaceSettingBlock -Settings ([ordered]@{ 'files.eol' = "`n" }) -MirrorFolderPath $mirrored)

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
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'The last explicit setting gets a comma, and a blank line sets the mirrored ones apart'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a key the mirrored file also sets
    $settings = [ordered]@{
        'files.eol'      = "`n"
        'editor.tabSize' = 4
    }

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-WorkspaceSettingBlock -Settings $settings -MirrorFolderPath $mirrored
    } -MessageLike "*both -Setting and*settings.json*'editor.tabSize'*" `
        -Message 'A key set both explicitly and by the mirrored file is refused, naming it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a mirrored file whose object holds only a note
    $noteOnly = Join-Path $root 'note-only'
    New-Item -ItemType Directory -Path (Join-Path $noteOnly '.vscode') | Out-Null
    [File]::WriteAllText((Join-Path $noteOnly '.vscode' 'settings.json'), "{`n  // nothing set yet`n}")

    # Act
    $lines = @(Get-WorkspaceSettingBlock -Settings ([ordered]@{ 'files.eol' = "`n" }) -MirrorFolderPath $noteOnly)

    # Assert
    $expected = @(
        '  "settings": {'
        '    "files.eol": "\n"'
        ''
        '    // Mirrored from .vscode/settings.json, because VS Code ignores'
        '    // window-scoped folder settings in a multi-root workspace.'
        '    // nothing set yet'
        '  }'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'The last explicit setting gets no comma when the mirrored file brings no key'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - settings named like the dictionary's own Keys property
    $settings = [ordered]@{
        'Keys'   = 1
        'Values' = 2
    }

    # Act
    $lines = @(Get-WorkspaceSettingBlock -Settings $settings)

    # Assert
    $expected = @(
        '  "settings": {'
        '    "Keys": 1,'
        '    "Values": 2'
        '  }'
    )
    Assert-Equal -Expected $expected -Actual $lines -Message 'Settings named Keys and Values are written like any other'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a value that is not JSON, and cheap for ConvertTo-Json to walk
    # had it not been refused
    $settings = @{ 'dotnet.defaultSolution' = [guid]::Empty }

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-WorkspaceSettingBlock -Settings $settings
    } -MessageLike "*Setting 'dotnet.defaultSolution' has a value of type System.Guid, which is not JSON*" `
        -Message 'A value that is not JSON is refused, naming the setting'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
