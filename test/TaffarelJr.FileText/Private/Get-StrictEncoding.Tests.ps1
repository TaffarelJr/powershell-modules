#Requires -Version 7.4
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$module = Get-Module TaffarelJr.FileText

#───────────────────────────────────────────────────────────────────────────────
# Arrange - built-in encodings, which substitute for what they cannot map
$ascii = & $module { Get-StrictEncoding -Encoding ([Encoding]::ASCII) }
$latin = & $module { Get-StrictEncoding -Encoding ([Encoding]::GetEncoding(28591)) }

# Act / Assert
Assert-Throws `
    -ScriptBlock { $ascii.GetString([byte[]](0xC3, 0xA9)) } `
    -MessageLike '*translate bytes*' `
    -Message 'A strict copy refuses bytes it cannot decode'
Assert-Throws `
    -ScriptBlock { $ascii.GetBytes("caf$([char]0xE9)") } `
    -MessageLike '*translate Unicode character*' `
    -Message 'and characters it cannot encode'
Assert-Throws `
    -ScriptBlock { $latin.GetBytes("$([char]0x20AC)") } `
    -MessageLike '*translate Unicode character*' `
    -Message 'whichever code page it is'
Assert-Equal -Expected 'iso-8859-1' -Actual $latin.WebName -Message 'and it is still the same encoding'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the built-in Unicode encodings, which all carry a mark
$cases = @(
    @{
        Name     = 'UTF-8'
        Encoding = [Encoding]::UTF8
        Type     = 'UTF8Encoding'
        Mark     = [byte[]](0xEF, 0xBB, 0xBF)
    }
    @{
        Name     = 'UTF-16 little-endian'
        Encoding = [Encoding]::Unicode
        Type     = 'UnicodeEncoding'
        Mark     = [byte[]](0xFF, 0xFE)
    }
    @{
        Name     = 'UTF-16 big-endian'
        Encoding = [Encoding]::BigEndianUnicode
        Type     = 'UnicodeEncoding'
        Mark     = [byte[]](0xFE, 0xFF)
    }
    @{
        Name     = 'UTF-32 little-endian'
        Encoding = [Encoding]::UTF32
        Type     = 'UTF32Encoding'
        Mark     = [byte[]](0xFF, 0xFE, 0x00, 0x00)
    }
    @{
        Name     = 'UTF-32 big-endian'
        Encoding = [UTF32Encoding]::new($true, $true)
        Type     = 'UTF32Encoding'
        Mark     = [byte[]](0x00, 0x00, 0xFE, 0xFF)
    }
)

foreach ($case in $cases) {
    # Act
    $kept = & $module { param($e) Get-StrictEncoding -Encoding $e } $case.Encoding
    $bare = & $module { param($e) Get-StrictEncoding -Encoding $e -WithoutPreamble } $case.Encoding

    # Assert
    Assert-Equal -Expected $case.Mark -Actual $kept.GetPreamble() -Message "$($case.Name) keeps its mark by default"
    Assert-Equal `
        -Expected ([byte[]]@()) `
        -Actual $bare.GetPreamble() `
        -Message "$($case.Name) loses it with -WithoutPreamble"
    Assert-Equal `
        -Expected $case.Type `
        -Actual $bare.GetType().Name `
        -Message "$($case.Name) is still $($case.Type) without it"
    Assert-Equal `
        -Expected $case.Encoding.GetBytes('hi') `
        -Actual $bare.GetBytes('hi') `
        -Message "$($case.Name) in the same byte order"
    Assert-Throws `
        -ScriptBlock { $bare.GetBytes("$([char]0xD800)") } `
        -MessageLike '*translate Unicode character*' `
        -Message "$($case.Name) without its mark is strict too"
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$plain = & $module { Get-StrictEncoding -Encoding ([Encoding]::GetEncoding(28591)) -WithoutPreamble }

# Assert
Assert-Equal `
    -Expected 'iso-8859-1' `
    -Actual $plain.WebName `
    -Message 'An encoding with no mark to drop comes back as a strict copy of itself'

exit (Complete-TestRun)
