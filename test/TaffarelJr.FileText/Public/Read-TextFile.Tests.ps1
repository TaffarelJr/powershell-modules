#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a UTF-8-with-BOM, CRLF file
    $path = Join-Path $sandbox 'bom.txt'
    [File]::WriteAllText($path, "line one`r`nline two`r`n", [UTF8Encoding]::new($true))

    # Act
    $file = Read-TextFile -Path $path

    # Assert
    Assert-Equal -Expected "line one`r`nline two`r`n" -Actual $file.Content `
        -Message 'Content comes back BOM-stripped, as plain text'
    Assert-Equal -Expected 3 -Actual $file.Encoding.GetPreamble().Length `
        -Message 'Encoding still reports the BOM the file actually has'
    Assert-Equal -Expected "`r`n" -Actual $file.LineEnding -Message 'LineEnding reflects what the content actually uses'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same text in each encoding that has a mark
    $cases = @(
        @{ Name = 'UTF-16 little-endian'; Encoding = [UnicodeEncoding]::new($false, $true) }
        @{ Name = 'UTF-16 big-endian'; Encoding = [UnicodeEncoding]::new($true, $true) }
        @{ Name = 'UTF-32 little-endian'; Encoding = [UTF32Encoding]::new($false, $true) }
        @{ Name = 'UTF-32 big-endian'; Encoding = [UTF32Encoding]::new($true, $true) }
    )

    foreach ($case in $cases) {
        # Act
        $encodedPath = Join-Path $sandbox "$([Guid]::NewGuid()).txt"
        [File]::WriteAllText($encodedPath, "caf$([char]0xE9)`n", $case.Encoding)
        $decoded = Read-TextFile -Path $encodedPath

        # Assert
        Assert-Equal -Expected "caf$([char]0xE9)`n" -Actual $decoded.Content `
            -Message "$($case.Name) text is decoded, mark removed"
        Assert-Equal -Expected $case.Encoding.GetPreamble() -Actual $decoded.Encoding.GetPreamble() `
            -Message "$($case.Name) comes back with its own mark"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - text in Windows-1252 / Latin-1, which has no mark and is not valid UTF-8
    $latin = Join-Path $sandbox 'latin1.txt'
    [File]::WriteAllBytes($latin, [Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9)"))

    # Act / Assert
    Assert-Throws -ScriptBlock { Read-TextFile -Path $latin } `
        -MessageLike '*latin1.txt*is not valid utf-8 text*', '*pass -Encoding*' `
        -Message 'Text that is not valid UTF-8 is refused, naming the file and the way out, rather than read with replacement characters'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the same file, read as what it is
    $asLatin = Read-TextFile -Path $latin -Encoding ([Encoding]::GetEncoding(28591))

    # Assert
    Assert-Equal -Expected "caf$([char]0xE9)" -Actual $asLatin.Content `
        -Message '-Encoding reads a file with no mark as that encoding'
    Assert-Equal -Expected 'iso-8859-1' -Actual $asLatin.Encoding.WebName `
        -Message 'and hands that encoding back, so a write can put it back the same way'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-8 text, read with an encoding that cannot decode all of it
    $accented = New-TestFile `
        -Directory $sandbox `
        -Name 'accented.txt' `
        -Byte ([Encoding]::UTF8.GetBytes("caf$([char]0xE9)"))

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Read-TextFile -Path $accented -Encoding ([Encoding]::ASCII) } `
        -MessageLike '*accented.txt*is not valid us-ascii text*' `
        -Message 'An -Encoding that cannot decode the file is refused, not read with question marks'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with no mark, read with an encoding object that has one
    $bare = New-TestFile -Directory $sandbox -Name 'bare.txt' -Byte ([byte[]](0x61, 0x62, 0x63, 0x0A))

    # Act
    $bareFile = Read-TextFile -Path $bare -Encoding ([Encoding]::UTF8)
    Write-TextFile -Path $bare -Content $bareFile.Content -Encoding $bareFile.Encoding

    # Assert
    Assert-Equal `
        -Expected ([byte[]](0x61, 0x62, 0x63, 0x0A)) `
        -Actual ([File]::ReadAllBytes($bare)) `
        -Message 'The Encoding read, passed to Write-TextFile, writes the file as it was, adding no mark'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files listed by Get-ChildItem
    $piped = Join-Path $sandbox 'piped'
    New-Item -ItemType Directory -Path $piped | Out-Null
    [File]::WriteAllText((Join-Path $piped 'a.txt'), 'first')
    [File]::WriteAllText((Join-Path $piped 'b.txt'), 'second')
    $listed = @(Get-ChildItem -LiteralPath $piped -File | Sort-Object Name)

    # Act
    $pipedFiles = @($listed | Read-TextFile)

    # Assert
    Assert-Equal `
        -Expected @('first', 'second') `
        -Actual @($pipedFiles.Content) `
        -Message 'Files piped in are each read, in order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same files as path strings, a Get-Content list, and Resolve-Path output
    $list = Join-Path $sandbox 'list.txt'
    Set-Content -LiteralPath $list -Value $listed.FullName

    # Act
    $fromStrings = @($listed.FullName | Read-TextFile)
    $fromList = @(Get-Content -LiteralPath $list | Read-TextFile)
    $fromResolved = @(Resolve-Path -LiteralPath $listed.FullName | Read-TextFile)

    # Assert
    Assert-Equal -Expected @('first', 'second') -Actual @($fromStrings.Content) `
        -Message 'Path strings piped in are each read'
    Assert-Equal -Expected @('first', 'second') -Actual @($fromList.Content) `
        -Message 'and so are the lines of a file list'
    Assert-Equal -Expected @('first', 'second') -Actual @($fromResolved.Content) `
        -Message 'and Resolve-Path output, by its Path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a UTF-8 BOM file, read with an encoding that disagrees
    $marked = Join-Path $sandbox 'marked.txt'
    [File]::WriteAllText($marked, "caf$([char]0xE9)", [UTF8Encoding]::new($true))

    # Act
    $override = Read-TextFile -Path $marked -Encoding ([Encoding]::GetEncoding(28591))

    # Assert
    Assert-Equal -Expected "caf$([char]0xE9)" -Actual $override.Content `
        -Message 'A byte order mark still decides over -Encoding'
    Assert-Equal -Expected 'utf-8' -Actual $override.Encoding.WebName `
        -Message 'and the file is reported as what the mark says'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $empty = New-TestFile -Directory $sandbox -Name 'empty.txt' -Byte ([byte[]]@())

    # Act
    $none = Read-TextFile -Path $empty

    # Assert
    Assert-Equal -Expected '' -Actual $none.Content -Message 'An empty file reads as empty content'
    Assert-Equal -Expected ([Environment]::NewLine) -Actual $none.LineEnding `
        -Message 'with the platform line ending, there being none to read'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null
    [File]::WriteAllText((Join-Path $here 'f.txt'), 'the right one')
    [File]::WriteAllText((Join-Path $there 'f.txt'), 'the wrong one')

    # Act
    $relative = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock { Read-TextFile -Path .\f.txt }

    # Assert
    Assert-Equal -Expected 'the right one' -Actual $relative.Content `
        -Message 'A relative path means the file in PowerShell''s location, not in the process''s working directory'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an object that carries only a PSPath, as an item of the file system provider does
    $pipedFile = Join-Path $sandbox 'pspath.txt'
    [File]::WriteAllText($pipedFile, 'bound by PSPath')
    $psPathOnly = [PSCustomObject]@{ PSPath = "Microsoft.PowerShell.Core\FileSystem::$pipedFile" }

    # Act
    $byPsPath = $psPathOnly | Read-TextFile
    $byItem = Get-Item -LiteralPath $pipedFile | Read-TextFile

    # Assert
    Assert-Equal -Expected 'bound by PSPath' -Actual $byPsPath.Content `
        -Message 'An object with only a PSPath is read by it, as a provider-qualified path'
    Assert-Equal -Expected 'bound by PSPath' -Actual $byItem.Content `
        -Message 'and so is the item Get-Item returns, which carries a PSPath and a FullName'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a file that is not there, and a folder
    Assert-Throws -ScriptBlock { Read-TextFile -Path (Join-Path $sandbox 'nope.txt') } `
        -MessageLike "No such file: '*nope.txt'*" `
        -Message 'A missing file says so, naming it'
    Assert-Throws -ScriptBlock { Read-TextFile -Path $sandbox } -MessageLike '*is a folder, not a file*' `
        -Message 'A folder says it is a folder'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a blank path
    Assert-Throws -ScriptBlock { Read-TextFile -Path '  ' } -MessageLike 'The path is blank*' `
        -Message 'A blank path is refused as blank, not taken to mean the current folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file another program holds open
    $held = Join-Path $sandbox 'held.txt'
    [File]::WriteAllText($held, 'text')
    $hold = Lock-TestFile -Path $held

    # Act / Assert
    try {
        Assert-Throws -ScriptBlock { Read-TextFile -Path $held } `
            -MessageLike ([WildcardPattern]::Escape("Cannot read '$held': ") + '*being used by another process*') `
            -Message 'A file held open by another program says it cannot read the file, and why'
    }
    finally {
        $hold.Dispose()
    }
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
