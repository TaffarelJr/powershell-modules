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
    . (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private' "$name.ps1")
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
$folder = @([PSCustomObject]@{ Path = $repo; Name = $null; Comment = $null })
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = @(Get-WorkspaceContent -Directory $repo -Folder $folder)

    # Assert
    $expected = @(
        '{'
        '  "folders": ['
        '    { "path": "." }'
        '  ]'
        '}'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'Folders alone make a complete file, with nothing after them'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = @(Get-WorkspaceContent -Directory $repo -Folder $folder -Comment 'first', 'second')

    # Assert
    Assert-Equal -Expected @('{', '  // first', '  // second', '  "folders": [') -Actual $lines[0..3] `
        -Message 'Comment lines sit between the opening brace and the first section'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = @(Get-WorkspaceContent -Directory $repo -Folder $folder -Settings @{ 'a' = 1 } -Extension 'x.y')
    $text = $lines -join "`n"
    $parsed = ConvertFrom-Json -InputObject $text

    # Assert
    Assert-Equal -Expected 1 -Actual $parsed.settings.a `
        -Message 'All three sections together are valid JSON, settings included'
    Assert-Equal -Expected @('x.y') -Actual @($parsed.extensions.recommendations) `
        -Message 'All three sections together are valid JSON, extensions included'
    Assert-That -Condition ($text.Contains("  ],`n  `"settings`"")) -Message 'A comma follows the folders section'
    Assert-That -Condition ($text.Contains("  },`n  `"extensions`"")) -Message 'A comma follows the settings section'
    Assert-That -Condition ($text.Contains("  }`n}")) -Message 'No comma follows the last section'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $lines = @(Get-WorkspaceContent -Directory $repo -Folder $folder -Extension 'x.y')
    $text = $lines -join "`n"

    # Assert
    Assert-That -Condition (-not $text.Contains('"settings"')) -Message 'A section with nothing in it is left out'
    Assert-That -Condition ($text.Contains("  ],`n  `"extensions`"")) `
        -Message 'The comma follows folders when extensions comes next'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
