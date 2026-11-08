#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $plain = Join-Path $sandbox 'plain.txt'
    [File]::WriteAllText($plain, "caf$([char]0xE9)`r`n", [UTF8Encoding]::new($false))

    # Act
    $result = & $module { param($p) Read-DecodedText -Path $p } $plain

    # Assert
    Assert-Equal -Expected "caf$([char]0xE9)`r`n" -Actual $result.Content `
        -Message 'Valid UTF-8 with no mark is decoded as it is'
    Assert-Equal -Expected 'utf-8' -Actual $result.Encoding.WebName -Message 'and reported as UTF-8'
    Assert-That -Condition ($null -eq $result.Problem) -Message 'with nothing wrong with it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - text in each encoding that has a mark
    $cases = @(
        @{ Name = 'UTF-8'; Encoding = [UTF8Encoding]::new($true) }
        @{ Name = 'UTF-16 little-endian'; Encoding = [UnicodeEncoding]::new($false, $true) }
        @{ Name = 'UTF-16 big-endian'; Encoding = [UnicodeEncoding]::new($true, $true) }
        @{ Name = 'UTF-32 little-endian'; Encoding = [UTF32Encoding]::new($false, $true) }
        @{ Name = 'UTF-32 big-endian'; Encoding = [UTF32Encoding]::new($true, $true) }
    )

    foreach ($case in $cases) {
        # Act
        $marked = Join-Path $sandbox "$([Guid]::NewGuid()).txt"
        [File]::WriteAllText($marked, "caf$([char]0xE9)", $case.Encoding)
        $decoded = & $module { param($p) Read-DecodedText -Path $p } $marked

        # Assert
        Assert-Equal -Expected "caf$([char]0xE9)" -Actual $decoded.Content `
            -Message "$($case.Name) is decoded, with its mark taken off the front"
        Assert-Equal -Expected $case.Encoding.GetPreamble() -Actual $decoded.Encoding.GetPreamble() `
            -Message "$($case.Name) comes back as the encoding that wrote it"
        Assert-That -Condition ($null -eq $decoded.Problem) -Message "$($case.Name) has no problem"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Windows-1252 text: not valid UTF-8, and no mark to say otherwise
    $latin = New-TestFile -Directory $sandbox -Name 'latin1.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9) ok"))

    # Act
    $loose = & $module { param($p) Read-DecodedText -Path $p } $latin

    # Assert
    Assert-Equal -Expected "caf$([char]0xFFFD) ok" -Actual $loose.Content `
        -Message 'The text still comes back, with a replacement character where the bad byte was, so a caller can look for a token in it'
    Assert-That `
        -Condition ($loose.Problem -like "'*latin1.txt' is not valid utf-8 text: *[E9]*Rewriting it would corrupt it; pass -Encoding*") `
        -Message 'and Problem names the file, the byte, and the way out'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-16 that stops in the middle of a character
    $cut = New-TestFile -Directory $sandbox -Name 'cut.txt' -Byte ([byte[]](0xFF, 0xFE, 0x68, 0x00, 0x69))

    # Act
    $cutResult = & $module { param($p) Read-DecodedText -Path $p } $cut

    # Assert
    Assert-Equal -Expected 'utf-16' -Actual $cutResult.Encoding.WebName `
        -Message 'A bad file in an encoding other than UTF-8 is reported in that encoding'
    Assert-That -Condition ($cutResult.Problem -like '*is not valid utf-16 text*') -Message 'with its own Problem'
    Assert-Equal -Expected "h$([char]0xFFFD)" -Actual $cutResult.Content `
        -Message 'and what could be decoded is still returned, with a replacement character for the rest'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - an encoding given for a file with no mark
    $asLatin = & $module { param($p, $e) Read-DecodedText -Path $p -Encoding $e } $latin ([Encoding]::GetEncoding(28591))

    # Assert
    Assert-Equal -Expected "caf$([char]0xE9) ok" -Actual $asLatin.Content `
        -Message 'A file with no mark is decoded as the encoding given'
    Assert-Equal -Expected 'iso-8859-1' -Actual $asLatin.Encoding.WebName -Message 'and reported as it'
    Assert-That -Condition ($null -eq $asLatin.Problem) -Message 'with nothing wrong'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-8 text with no mark, and encodings given as the built-in objects
    $accented = New-TestFile `
        -Directory $sandbox `
        -Name 'accented.txt' `
        -Byte ([Encoding]::UTF8.GetBytes("caf$([char]0xE9)"))

    # Act
    $asAscii = & $module { param($p) Read-DecodedText -Path $p -Encoding ([Encoding]::ASCII) } $accented
    $asUtf8 = & $module { param($p) Read-DecodedText -Path $p -Encoding ([Encoding]::UTF8) } $accented

    # Assert
    Assert-That `
        -Condition ($asAscii.Problem -like "'*accented.txt' is not valid us-ascii text: *") `
        -Message 'An encoding given is used strictly, so what it cannot decode is a Problem, not quietly replaced'
    Assert-Equal -Expected "caf$([char]0xE9)" -Actual $asUtf8.Content -Message 'An encoding that fits decodes the text'
    Assert-Equal `
        -Expected ([byte[]]@()) `
        -Actual $asUtf8.Encoding.GetPreamble() `
        -Message 'and comes back without a mark, since the file has none'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a UTF-8 file with a mark, and an encoding that disagrees
    $marked = Join-Path $sandbox 'marked.txt'
    [File]::WriteAllText($marked, "caf$([char]0xE9)", [UTF8Encoding]::new($true))

    # Act
    $marker = & $module { param($p, $e) Read-DecodedText -Path $p -Encoding $e } $marked ([Encoding]::GetEncoding(28591))

    # Assert
    Assert-Equal -Expected "caf$([char]0xE9)" -Actual $marker.Content `
        -Message 'A byte order mark outranks the encoding given'
    Assert-Equal -Expected 'utf-8' -Actual $marker.Encoding.WebName -Message 'and decides the encoding reported'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $empty = New-TestFile -Directory $sandbox -Name 'empty.txt' -Byte ([byte[]]@())
    $markOnly = New-TestFile -Directory $sandbox -Name 'mark-only.txt' -Byte ([byte[]](0xEF, 0xBB, 0xBF))

    # Act
    $emptyResult = & $module { param($p) Read-DecodedText -Path $p } $empty
    $markResult = & $module { param($p) Read-DecodedText -Path $p } $markOnly

    # Assert
    Assert-Equal -Expected '' -Actual $emptyResult.Content -Message 'An empty file decodes to empty text'
    Assert-Equal -Expected '' -Actual $markResult.Content -Message 'and so does one that is only a mark'
    Assert-Equal -Expected 3 -Actual $markResult.Encoding.GetPreamble().Length -Message 'which still remembers the mark'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file another program holds open
    $held = Join-Path $sandbox 'held.txt'
    [File]::WriteAllText($held, 'text')
    $hold = Lock-TestFile -Path $held

    # Act / Assert
    try {
        Assert-Throws -ScriptBlock { & $module { param($p) Read-DecodedText -Path $p } $held } `
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
