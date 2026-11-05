#Requires -Version 7.4
using namespace System.IO

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
    # Arrange - notes before and after the object that hold braces of their own
    $content = "// see {the docs} for these`n/* and {this} */`n{`n  `"a`": 1`n}`n// closing } of nothing`n/* nor {this */"
    $folder = New-SettingsFolder -Root $root -Name 'braced-notes' -Content $content

    # Act
    $body = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected @('    "a": 1') -Actual $body.Lines `
        -Message 'A brace in a note before or after the object is not taken for its edge'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - braces, quotes, and comment markers inside strings
    $content = "{`n  `"a`": `"x{y\`"}z`",`n  `"b`": `"// not a note`",`n  `"c`": `"/* nor this`"`n}"
    $folder = New-SettingsFolder -Root $root -Name 'braced-strings' -Content $content

    # Act
    $body = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    $expected = @('    "a": "x{y\"}z",', '    "b": "// not a note",', '    "c": "/* nor this"')
    Assert-Equal -Expected $expected -Actual $body.Lines `
        -Message 'What a string holds is not read as braces, a note, or the end of the string'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a block comment holding an asterisk, a zero-width joiner and a slash,
    # which a comparison that ignores such characters would read as the end of the comment
    $joiner = [string][char]0x200D
    $content = "{`n  /* not the end: *$joiner/ still a note, with a } in it */`n  `"a`": 1`n}"
    $folder = New-SettingsFolder -Root $root -Name 'joiner-note' -Content $content

    # Act
    $joinerBody = Get-FolderSettingsBody -FolderPath $folder

    # Assert
    Assert-Equal -Expected @("    /* not the end: *$joiner/ still a note, with a } in it */", '    "a": 1') `
        -Actual $joinerBody.Lines `
        -Message 'A zero-width joiner between the * and the / does not end the comment'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a note ended by a lone CR, which the parser accepts; a walker
    # that missed it would find no closing brace and throw
    $crNote = New-SettingsFolder -Root $root -Name 'cr-note' -Content "{`r  // note`r  `"a`": 1`r}"

    # Act
    $crNoteLines = try {
        (Get-FolderSettingsBody -FolderPath $crNote).Lines
    }
    catch {
        "threw: $($_.Exception.Message)"
    }

    # Assert
    Assert-Equal -Expected @('    // note', '    "a": 1') -Actual $crNoteLines `
        -Message 'A note ends at a lone CR, not at the end of the file'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a single-quoted string holding a brace, which the parser accepts
    $quoted = New-SettingsFolder -Root $root -Name 'single-quoted' -Content "{`n  'a': '{'`n}"

    # Act
    $quotedBody = Get-FolderSettingsBody -FolderPath $quoted

    # Assert
    Assert-Equal -Expected @("    'a': '{'") -Actual $quotedBody.Lines `
        -Message 'A brace inside a single-quoted string is not taken for an edge'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files that are not valid JSON, which would break the workspace
    # file they were spliced into
    $invalid = @(
        @{ Name = 'no-object'; Content = 'just a note, no braces'; Message = 'Text with no object in it' }
        @{ Name = 'unclosed'; Content = "{`n  `"a`": {`n    `"b`": 1`n  }"; Message = 'An object that is never closed' }
        @{ Name = 'open-string'; Content = "{ `"a`": `"never ends }"; Message = 'A string that is never closed' }
        @{ Name = 'open-note'; Content = "{`n  `"a`": 1`n} /* never ends"; Message = 'A note that is never closed' }
        @{
            Name = 'two-objects'
            Content = "{`n  `"first`": 1`n}`n{`n  `"second`": 2`n}"
            Message = 'A second object after the first'
        }
        @{ Name = 'garbage'; Content = '{ garbage here }'; Message = 'An object with no valid entries' }
        @{ Name = 'text-first'; Content = '"x" { "a": 1 }'; Message = 'A string ahead of the object' }
    )

    # Act / Assert
    foreach ($case in $invalid) {
        $folder = New-SettingsFolder -Root $root -Name $case.Name -Content $case.Content
        $pattern = "*is not valid JSON*$([WildcardPattern]::Escape($folder))*settings.json*"
        Assert-Throws -ScriptBlock {
            Get-FolderSettingsBody -FolderPath $folder
        } -MessageLike $pattern -Message "$($case.Message) is refused, naming the file"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - valid JSON, but not an object
    $notObject = @(
        @{ Name = 'array'; Content = '[ { "a": 1 } ]'; Message = 'An array holding an object' }
        @{ Name = 'string'; Content = '"editor.tabSize"'; Message = 'A lone string' }
    )

    # Act / Assert
    foreach ($case in $notObject) {
        $folder = New-SettingsFolder -Root $root -Name $case.Name -Content $case.Content
        $pattern = "*does not hold a JSON object*$([WildcardPattern]::Escape($folder))*settings.json*"
        Assert-Throws -ScriptBlock {
            Get-FolderSettingsBody -FolderPath $folder
        } -MessageLike $pattern -Message "$($case.Message) is refused, naming the file"
    }
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
