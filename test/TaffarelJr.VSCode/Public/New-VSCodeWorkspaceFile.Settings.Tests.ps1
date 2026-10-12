#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - setting values that are not JSON, and cheap for ConvertTo-Json
    # to walk had they not been refused
    $ws = Join-Path $repo 'not-json.code-workspace'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Setting @{ 'dotnet.defaultSolution' = [guid]::Empty }
    } -MessageLike "*Setting 'dotnet.defaultSolution' has a value of type System.Guid, which is not JSON*" `
        -Message 'A Guid value is refused, naming the setting'
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Setting @{ 'my.link' = [uri]'https://example.com/' }
    } -MessageLike "*Setting 'my.link' has a value of type System.Uri*" `
        -Message 'A Uri value is refused, naming the setting'
    Assert-That -Condition (-not (Test-Path -LiteralPath $ws)) -Message 'No file is written when a setting is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a setting nested twelve levels deep
    $ws = Join-Path $repo 'deep.code-workspace'
    $deep = @{ l1 = @{ l2 = @{ l3 = @{ l4 = @{ l5 = @{ l6 = @{ l7 = @{ l8 = @{ l9 = @{ l10 = @{ l11 = @{ l12 = 'bottom' } } } } } } } } } } } }

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Setting @{ deep = $deep }
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    $bottom = $parsed.settings.deep.l1.l2.l3.l4.l5.l6.l7.l8.l9.l10.l11.l12
    Assert-Equal -Expected 'bottom' -Actual $bottom -Message 'A setting nested twelve levels deep is written whole'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a hand-edited file, overwritten with text no UTF-8 can hold
    $ws = Join-Path $repo 'keep.code-workspace'
    [File]::WriteAllText($ws, "{ `"hand-edited`": true }`r`n")
    $before = [File]::ReadAllBytes($ws)

    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Setting @{ x = 'a' + [char]0xD800 } -Force
    } -MessageLike '*Could not write the workspace file*keep.code-workspace*\uD800*' `
        -Message 'A lone surrogate cannot be written, and the module''s own message names the file'
    Assert-Equal -Expected $before -Actual ([File]::ReadAllBytes($ws)) `
        -Message 'and the existing file is left byte for byte as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder settings file that sets a key -Setting sets too
    $mirror = New-SettingsFolder -Root $root -Name 'shared-key' -Content "{`n  `"editor.tabSize`": 2`n}"
    $ws = Join-Path $repo 'shared-key.code-workspace'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Setting @{ 'editor.tabSize' = 4 } -MirrorSettingsFrom $mirror
    } -MessageLike "*both -Setting and*settings.json*'editor.tabSize'*" `
        -Message 'A key in both -Setting and the mirrored file is refused, naming it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - folder settings files a workspace file cannot take in
    $invalid = New-SettingsFolder -Root $root -Name 'invalid' -Content '{ garbage here }'
    $array = New-SettingsFolder -Root $root -Name 'array' -Content '[ { "a": 1 } ]'
    $ws = Join-Path $repo 'bad-mirror.code-workspace'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -MirrorSettingsFrom $invalid
    } -MessageLike '*is not valid JSON*invalid*settings.json*' `
        -Message 'A settings file that is not valid JSON is refused, naming it'
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -MirrorSettingsFrom $array
    } -MessageLike '*does not hold a JSON object*array*settings.json*' `
        -Message 'A settings file holding an array is refused, naming it'
    Assert-That -Condition (-not (Test-Path -LiteralPath $ws)) `
        -Message 'No file is written when the mirrored settings are refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an empty folder settings file, which VS Code accepts
    $empty = New-SettingsFolder -Root $root -Name 'empty' -Content ''
    $ws = Join-Path $repo 'empty-mirror.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -MirrorSettingsFrom $empty
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-That -Condition ($null -eq $parsed.PSObject.Properties['settings']) `
        -Message 'An empty settings file adds no settings section'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'names.code-workspace'
    $folder = @{
        Path = $repo
        Name = 7
    }

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $folder
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-Equal -Expected '7' -Actual $parsed.folders[0].name `
        -Message 'A folder name given as a number is written as a string'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'extensions.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Extension 'ms-vscode.powershell', 'MS-VSCode.PowerShell'
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-Equal -Expected @('ms-vscode.powershell') -Actual @($parsed.extensions.recommendations) `
        -Message 'An extension given twice in other casing is recommended once'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a setting with no name
    $ws = Join-Path $repo 'blank-key.code-workspace'

    # Act / Assert
    Assert-Throws -ScriptBlock { New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Setting @{ '' = 'x' } } `
        -MessageLike '*-Setting has a setting with a blank name*' `
        -Message 'A setting with an empty name is refused, saying so, not failing inside a helper'
    Assert-That -Condition (-not (Test-Path -LiteralPath $ws)) -Message 'and no workspace file is written'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - things that are not publisher.name extension ids
    $notIds = @(
        @{ Extension = ''; Message = 'An empty extension id is refused' }
        @{ Extension = 'not an id'; Message = 'An id with spaces is refused' }
        @{ Extension = 'nodot'; Message = 'An id with no publisher is refused' }
        @{ Extension = "a.b`n"; Message = 'An id followed by a line break is refused' }
    )
    $ws = Join-Path $repo 'bad-extension.code-workspace'

    # Act / Assert
    foreach ($case in $notIds) {
        Assert-Throws -ScriptBlock {
            New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Extension 'a.b', $case.Extension
        } -MessageLike '*Extension*' -Message $case.Message
    }
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
