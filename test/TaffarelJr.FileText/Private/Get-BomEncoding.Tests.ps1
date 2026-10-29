#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$module = Get-Module TaffarelJr.FileText

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every kind of start, and what it should be read as
$cases = @(
    @{ Name = 'no mark'; Bytes = [byte[]](0x68, 0x69); Type = 'UTF8Encoding'; Length = 0; Bom = $false }
    @{ Name = 'a UTF-8 mark'; Bytes = [byte[]](0xEF, 0xBB, 0xBF, 0x68); Type = 'UTF8Encoding'; Length = 3; Bom = $true }
    @{
        Name = 'a UTF-16 little-endian mark'
        Bytes = [byte[]](0xFF, 0xFE, 0x68, 0x00)
        Type = 'UnicodeEncoding'
        Length = 2
        Bom = $true
    }
    @{
        Name = 'a UTF-16 big-endian mark'
        Bytes = [byte[]](0xFE, 0xFF, 0x00, 0x68)
        Type = 'UnicodeEncoding'
        Length = 2
        Bom = $true
    }
    @{
        Name = 'a UTF-32 little-endian mark'
        Bytes = [byte[]](0xFF, 0xFE, 0x00, 0x00, 0x68, 0x00, 0x00, 0x00)
        Type = 'UTF32Encoding'
        Length = 4
        Bom = $true
    }
    @{
        Name = 'a UTF-32 big-endian mark'
        Bytes = [byte[]](0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0x00, 0x68)
        Type = 'UTF32Encoding'
        Length = 4
        Bom = $true
    }
    @{
        Name = 'a UTF-16 mark followed by a character, not a UTF-32 mark'
        Bytes = [byte[]](0xFF, 0xFE, 0x68, 0x00)
        Type = 'UnicodeEncoding'
        Length = 2
        Bom = $true
    }
    @{
        Name = 'a UTF-16 mark that is all there is'
        Bytes = [byte[]](0xFF, 0xFE)
        Type = 'UnicodeEncoding'
        Length = 2
        Bom = $true
    }
    @{ Name = 'a UTF-8 mark cut short'; Bytes = [byte[]](0xEF, 0xBB); Type = 'UTF8Encoding'; Length = 0; Bom = $false }
    @{
        Name = 'two NULs that are not a mark'
        Bytes = [byte[]](0x00, 0x00, 0x41)
        Type = 'UTF8Encoding'
        Length = 0
        Bom = $false
    }
    @{ Name = 'no bytes at all'; Bytes = [byte[]]@(); Type = 'UTF8Encoding'; Length = 0; Bom = $false }
)

foreach ($case in $cases) {
    # Act
    $result = & $module { param($b) Get-BomEncoding -Byte $b } $case.Bytes

    # Assert
    Assert-Equal -Expected $case.Type -Actual $result.Encoding.GetType().Name `
        -Message "$($case.Name) is read as $($case.Type)"
    Assert-Equal -Expected $case.Length -Actual $result.PreambleLength `
        -Message "$($case.Name) takes up $($case.Length) byte(s)"
    Assert-Equal -Expected $case.Bom -Actual ($result.Encoding.GetPreamble().Length -gt 0) `
        -Message "$($case.Name) is written back with a mark only if it was read with one"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a long file: only its start is looked at
$long = [byte[]](0xEF, 0xBB, 0xBF) + [byte[]]::new(10000)
$result = & $module { param($b) Get-BomEncoding -Byte $b } $long

# Assert
Assert-Equal -Expected 3 -Actual $result.PreambleLength -Message 'A mark at the start of a long file is found'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the encodings that come back
$plain = & $module { Get-BomEncoding -Byte ([byte[]](0x68)) }
$utf16 = & $module { Get-BomEncoding -Byte ([byte[]](0xFF, 0xFE, 0x68, 0x00)) }

# Act / Assert - none of them substitutes for what it cannot map
Assert-Throws -ScriptBlock { $plain.Encoding.GetString([byte[]](0xE9)) } -MessageLike '*translate bytes*' `
    -Message 'UTF-8 refuses a byte that starts no character'
Assert-Throws -ScriptBlock { $plain.Encoding.GetBytes("$([char]0xD800)") } `
    -MessageLike '*translate Unicode character*' `
    -Message 'and a character with no encoding'
Assert-Throws -ScriptBlock { $utf16.Encoding.GetString([byte[]](0x68)) } -MessageLike '*translate bytes*' `
    -Message 'UTF-16 refuses half a character'

exit (Complete-TestRun)
