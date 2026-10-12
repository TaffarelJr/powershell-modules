#Requires -Version 7.0
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'my repo'
$lib = Join-Path $root 'shared-lib'
New-Item -ItemType Directory -Path $repo, $lib | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'basic.code-workspace'

    # Act
    $returned = New-VSCodeWorkspaceFile -Path $ws -Folder $repo, $lib
    $parsed = Read-WorkspaceFile -Path $ws
    $text = [File]::ReadAllText($ws)

    # Assert
    Assert-Equal -Expected $ws -Actual $returned -Message 'The workspace file''s full path is returned'
    Assert-That -Condition (Test-Path -LiteralPath $ws) -Message 'The file is written'
    Assert-Equal -Expected 2 -Actual $parsed.folders.Count -Message 'Each folder given becomes an entry'
    Assert-Equal -Expected '.' -Actual $parsed.folders[0].path -Message 'The workspace file''s own folder is "."'
    Assert-Equal -Expected '../shared-lib' -Actual $parsed.folders[1].path -Message 'A sibling folder is relative to the workspace file''s folder'
    Assert-That -Condition (-not $text.Contains('\')) -Message 'No backslash appears anywhere in the file'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the workspace file in a different folder than the first
    # folder, with a space in the path it points back to
    $ws = Join-Path $lib 'elsewhere.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-Equal -Expected '../my repo' -Actual $parsed.folders[0].path -Message 'A path with a space is kept as is'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'named.code-workspace'
    $folders = @{ Path = $repo; Name = 'primary'; Comment = 'The primary folder.' }, $lib

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $folders
    $parsed = Read-WorkspaceFile -Path $ws
    $text = [File]::ReadAllText($ws)

    # Assert
    Assert-Equal -Expected 'primary' -Actual $parsed.folders[0].name -Message 'A folder''s Name becomes its display name'
    Assert-That -Condition ($null -eq $parsed.folders[1].PSObject.Properties['name']) -Message 'A folder given as a bare path gets no name'
    Assert-That -Condition ($text.Contains('// The primary folder.')) -Message 'A folder''s Comment is written above its entry'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'piped.code-workspace'

    # Act
    $null = Get-Item -LiteralPath $repo, $lib | New-VSCodeWorkspaceFile -Path $ws
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-Equal -Expected @('.', '../shared-lib') -Actual @($parsed.folders | ForEach-Object { $_.path }) -Message 'Piped directories become folders, in order'
    Assert-Equal -Expected @('my repo', 'shared-lib') -Actual @($parsed.folders | ForEach-Object { $_.name }) -Message 'A piped directory''s own name becomes its display name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'settings.code-workspace'
    $settings = [ordered]@{
        'editor.formatOnSave'    = $true
        'editor.rulers'          = @(80, 120)
        'files.exclude'          = @{ '**/bin' = $true }
        'dotnet.defaultSolution' = 'App.sln'
    }

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Settings $settings
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-Equal -Expected $true -Actual $parsed.settings.'editor.formatOnSave' -Message 'A boolean setting keeps its type'
    Assert-Equal -Expected @(80, 120) -Actual @($parsed.settings.'editor.rulers') -Message 'An array setting keeps its elements'
    Assert-Equal -Expected $true -Actual $parsed.settings.'files.exclude'.'**/bin' -Message 'A nested setting keeps its shape'
    Assert-Equal -Expected 'App.sln' -Actual $parsed.settings.'dotnet.defaultSolution' -Message 'A string setting keeps its value'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'extensions.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Extension 'ms-vscode.powershell', 'editorconfig.editorconfig'
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-Equal -Expected @('ms-vscode.powershell', 'editorconfig.editorconfig') -Actual @($parsed.extensions.recommendations) -Message 'Extension ids become recommendations, in order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'comments.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Comment 'Generated; local only.', 'Safe to delete.'
    $lines = Get-Content -LiteralPath $ws

    # Assert
    Assert-Equal -Expected '  // Generated; local only.' -Actual $lines[1] -Message 'The first comment line follows the opening brace'
    Assert-Equal -Expected '  // Safe to delete.' -Actual $lines[2] -Message 'Each comment element is its own line'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with its own settings file, comments and all
    $mirrorFolder = Join-Path $root 'mirror'
    New-Item -ItemType Directory -Path (Join-Path $mirrorFolder '.vscode') | Out-Null
    [File]::WriteAllText((Join-Path $mirrorFolder '.vscode' 'settings.json'), "{`n  // keep this note`n  `"editor.tabSize`": 2`n}")
    $ws = Join-Path $repo 'mirror.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Settings @{ 'files.eol' = "`n" } -MirrorSettingsFrom $mirrorFolder
    $parsed = Read-WorkspaceFile -Path $ws
    $text = [File]::ReadAllText($ws)

    # Assert
    Assert-Equal -Expected 2 -Actual $parsed.settings.'editor.tabSize' -Message 'A mirrored setting lands in the workspace settings'
    Assert-Equal -Expected "`n" -Actual $parsed.settings.'files.eol' -Message 'Explicit settings are kept alongside the mirrored ones'
    Assert-That -Condition ($text.Contains('// keep this note')) -Message 'A comment inside the mirrored settings survives'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with no settings file, and nothing else to put in
    $ws = Join-Path $repo 'no-settings.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -MirrorSettingsFrom $lib
    $parsed = Read-WorkspaceFile -Path $ws

    # Assert
    Assert-That -Condition ($null -eq $parsed.PSObject.Properties['settings']) -Message 'With nothing to mirror and no settings, no settings section is written'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file already there
    $ws = Join-Path $repo 'existing.code-workspace'
    [File]::WriteAllText($ws, '{ "hand-edited": true }')

    # Act
    $message = Get-ErrorMessage -ScriptBlock { New-VSCodeWorkspaceFile -Path $ws -Folder $repo }

    # Assert
    Assert-That -Condition ($message -like '*already exists*-Force*') -Message 'An existing file is refused, with the way around it'
    Assert-Equal -Expected '{ "hand-edited": true }' -Actual ([File]::ReadAllText($ws)) -Message 'The refused file is left untouched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an existing CRLF file with a byte-order mark
    $ws = Join-Path $repo 'forced.code-workspace'
    [File]::WriteAllText($ws, "stale-marker`r`n", [UTF8Encoding]::new($true))

    # Act
    $null = New-VSCodeWorkspaceFile -Path $ws -Folder $repo -Force
    $bytes = [File]::ReadAllBytes($ws)
    $text = [File]::ReadAllText($ws)

    # Assert
    Assert-That -Condition ($text -notmatch 'stale-marker') -Message '-Force overwrites the existing content'
    Assert-Equal -Expected ([byte[]]@(0xEF, 0xBB, 0xBF)) -Actual ([byte[]]$bytes[0..2]) -Message 'The existing byte-order mark is kept'
    Assert-That -Condition ($text -notmatch "(?<!`r)`n") -Message 'The existing CRLF line ending is kept'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $message = Get-ErrorMessage -ScriptBlock { New-VSCodeWorkspaceFile -Path (Join-Path $root 'no-such-folder' 'x.code-workspace') -Folder $repo }

    # Assert
    Assert-That -Condition ($message -like '*workspace file''s folder does not exist*') -Message 'A workspace file in a folder that does not exist is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ws = Join-Path $repo 'missing-folder.code-workspace'

    # Act
    $message = Get-ErrorMessage -ScriptBlock { New-VSCodeWorkspaceFile -Path $ws -Folder $repo, (Join-Path $root 'not-there') }

    # Assert
    Assert-That -Condition ($null -ne $message) -Message 'A workspace folder that does not exist is refused'
    Assert-That -Condition (-not (Test-Path -LiteralPath $ws)) -Message 'No file is written when a folder is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { New-VSCodeWorkspaceFile -Path (Join-Path $repo 'x.json') -Folder $repo } -Message 'A path that does not end in .code-workspace is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - relative paths, from a different current location than the
    # process's own
    Push-Location $root

    # Act
    $returned = New-VSCodeWorkspaceFile -Path 'my repo/relative.code-workspace' -Folder 'my repo', 'shared-lib'
    Pop-Location
    $parsed = Read-WorkspaceFile -Path $returned

    # Assert
    Assert-Equal -Expected (Join-Path $repo 'relative.code-workspace') -Actual $returned -Message 'A relative file path resolves against the current location'
    Assert-Equal -Expected @('.', '../shared-lib') -Actual @($parsed.folders | ForEach-Object { $_.path }) -Message 'Relative folder paths resolve against the current location too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - paths reached through a mapped PSDrive
    $null = New-PSDrive -Name VscWsLab -PSProvider FileSystem -Root $root -Scope Global

    # Act
    $returned = New-VSCodeWorkspaceFile -Path 'VscWsLab:/my repo/drive.code-workspace' -Folder 'VscWsLab:/my repo', 'VscWsLab:/shared-lib'
    Remove-PSDrive -Name VscWsLab
    $parsed = Read-WorkspaceFile -Path (Join-Path $repo 'drive.code-workspace')

    # Assert
    Assert-Equal -Expected (Join-Path $repo 'drive.code-workspace') -Actual $returned -Message 'A PSDrive path is returned as the real path'
    Assert-Equal -Expected @('.', '../shared-lib') -Actual @($parsed.folders | ForEach-Object { $_.path }) -Message 'Folders reached through a PSDrive are still relative to the real location'
}
finally {
    Remove-PSDrive -Name VscWsLab -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
