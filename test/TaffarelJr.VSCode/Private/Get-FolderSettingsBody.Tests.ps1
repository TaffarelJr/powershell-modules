#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-FolderSettingsBody.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with no .vscode at all
    $bare = Join-Path $root 'bare'
    New-Item -ItemType Directory -Path $bare | Out-Null

    # Act
    $bodies = @(Get-FolderSettingsBody -FolderPath $bare)

    # Assert
    Assert-Equal -Expected 0 -Actual $bodies.Count -Message 'No settings file means nothing to mirror'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $content = "{`n  `"editor.formatOnSave`": true,`n  `"editor.tabSize`": 2`n}"
    $folder = New-SettingsFolder -Root $root -Name 'plain' -Content $content

    # Act
    $body = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    $expected = @('    "editor.formatOnSave": true,', '    "editor.tabSize": 2')
    Assert-Equal -Expected $expected -Actual $body.Lines `
        -Message 'The body is returned one level deeper, braces left out'
    Assert-Equal -Expected @('editor.formatOnSave', 'editor.tabSize') -Actual $body.Keys `
        -Message 'The top-level keys come back, in file order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a leading note, an inline note, and a nested object
    $content = "// why these are set`n{`n  // keep this`n  `"files.exclude`": {`n    `"**/bin`": true`n  }`n}"
    $folder = New-SettingsFolder -Root $root -Name 'jsonc' -Content $content

    # Act
    $body = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    $expected = @('    // keep this', '    "files.exclude": {', '      "**/bin": true', '    }')
    Assert-Equal -Expected $expected -Actual $body.Lines `
        -Message 'Comments and nesting survive, and the leading note outside the braces is left behind'
    Assert-Equal -Expected @('files.exclude') -Actual $body.Keys `
        -Message 'Only top-level keys are listed, not nested ones'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - top-level keys named like the parsed dictionary's own
    # properties
    $content = "{`n  `"Keys`": 1,`n  `"Values`": 2`n}"
    $folder = New-SettingsFolder -Root $root -Name 'shadowing' -Content $content

    # Act
    $body = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected @('Keys', 'Values') -Actual $body.Keys `
        -Message 'Keys named Keys and Values are listed like any other'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - tab-indented
    $folder = New-SettingsFolder -Root $root -Name 'tabs' -Content "{`r`n`t`"editor.formatOnSave`": true`r`n}"

    # Act
    $body = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected @('    "editor.formatOnSave": true') -Actual $body.Lines `
        -Message 'A tab-indented file loses its tabs'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - CRLF line endings, and CR-only ones
    $crlf = New-SettingsFolder -Root $root -Name 'crlf' -Content "{`r`n  `"a`": 1,`r`n  `"b`": 2`r`n}"
    $cr = New-SettingsFolder -Root $root -Name 'cr' -Content "{`r  `"a`": 1,`r  `"b`": 2`r}"

    # Act
    $crlfBody = Get-FolderSettingsBody -FolderPath $crlf
    $crBody = Get-FolderSettingsBody -FolderPath $cr

    # Assert
    Assert-Equal -Expected @('    "a": 1,', '    "b": 2') -Actual $crlfBody.Lines `
        -Message 'CRLF endings split into lines with no carriage return left in them'
    Assert-Equal -Expected @('    "a": 1,', '    "b": 2') -Actual $crBody.Lines -Message 'and so do bare CR endings'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a UTF-8 file that starts with a byte order mark
    $content = "{`n  `"a`": 1`n}"
    $folder = New-SettingsFolder -Root $root -Name 'bom' -Content $content -Encoding ([UTF8Encoding]::new($true))

    # Act
    $body = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected @('    "a": 1') -Actual $body.Lines -Message 'A byte order mark is not carried into the body'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the whole object on one line, and content on the opening line
    $oneLine = New-SettingsFolder -Root $root -Name 'one-line' -Content '{ "a": 1, "b": 2 }'
    $opening = New-SettingsFolder -Root $root -Name 'opening' -Content "{ `"a`": 1,`n  `"b`": 2`n}"

    # Act
    $oneLineBody = Get-FolderSettingsBody -FolderPath $oneLine
    $openingBody = Get-FolderSettingsBody -FolderPath $opening

    # Assert
    Assert-Equal -Expected @('    "a": 1, "b": 2') -Actual $oneLineBody.Lines `
        -Message 'A one-line object leaves no stray space behind'
    Assert-Equal -Expected @('    "a": 1,', '    "b": 2') -Actual $openingBody.Lines `
        -Message 'Content on the opening line does not push the lines below it deeper'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an object with nothing in it
    $folder = New-SettingsFolder -Root $root -Name 'empty-object' -Content "{`n}"

    # Act
    $bodies = @(Get-FolderSettingsBody -FolderPath $folder)

    # Assert
    Assert-Equal -Expected 0 -Actual $bodies.Count -Message 'An empty object has nothing to mirror'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files VS Code accepts as holding no settings at all
    $blank = @(
        @{ Name = 'empty-file'; Content = ''; Message = 'An empty file' }
        @{ Name = 'blank-file'; Content = "  `r`n `t"; Message = 'A file of only whitespace' }
        @{ Name = 'notes-only'; Content = "// nothing set yet`n"; Message = 'A file of only a note' }
    )

    # Act / Assert
    foreach ($case in $blank) {
        $folder = New-SettingsFolder -Root $root -Name $case.Name -Content $case.Content
        $bodies = @(Get-FolderSettingsBody -FolderPath $folder)
        Assert-Equal -Expected 0 -Actual $bodies.Count -Message "$($case.Message) has nothing to mirror"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a settings file in Latin-1, with an accented letter and no byte order mark
    $latin = New-SettingsFolder -Root $root -Name 'latin-one' -Encoding ([Encoding]::GetEncoding(28591)) `
        -Content "{`n  `"a`": `"caf$([char]0xE9)`"`n}"

    # Act / Assert
    Assert-Throws -ScriptBlock { Get-FolderSettingsBody -FolderPath $latin } `
        -MessageLike '*settings file cannot be read, so it cannot be mirrored*not valid utf-8 text*' `
        -Message 'A file that is not UTF-8 is refused, rather than mirrored with replacement characters'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a UTF-8 settings file with a byte order mark and an accented letter
    $marked = New-SettingsFolder -Root $root -Name 'utf8-bom' -Encoding ([UTF8Encoding]::new($true)) `
        -Content "{`n  `"a`": `"caf$([char]0xE9)`"`n}"

    # Act
    $markedBody = Get-FolderSettingsBody -FolderPath $marked

    # Assert
    Assert-Equal -Expected @("    `"a`": `"caf$([char]0xE9)`"") -Actual $markedBody.Lines `
        -Message 'A UTF-8 file with a byte order mark is read as the text it holds, mark left out'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
