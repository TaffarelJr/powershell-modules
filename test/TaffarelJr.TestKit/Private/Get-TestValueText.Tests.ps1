#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

$exists = Test-Path -LiteralPath $PSScriptRoot
$cases = @(
    @{ Name = '$null'; Value = $null; Expected = 'null' }
    @{ Name = 'an empty string'; Value = ''; Expected = '""' }
    @{ Name = 'a string with a space'; Value = 'a b'; Expected = '"a b"' }
    @{ Name = 'a number'; Value = 5; Expected = '5' }
    @{ Name = 'a double'; Value = 0.1; Expected = '0.1' }
    @{ Name = 'a float'; Value = [float]0.1; Expected = '0.1' }
    @{ Name = 'a float widened to a double'; Value = [double][float]0.1; Expected = '0.10000000149011612' }
    @{ Name = 'a whole double'; Value = 3.0; Expected = '3' }
    @{ Name = 'a double too large for its digits'; Value = 1e300; Expected = '1E+300' }
    @{ Name = 'a double that is not a number'; Value = [double]::NaN; Expected = 'NaN' }
    @{ Name = 'an infinite float'; Value = [float]::NegativeInfinity; Expected = '-Infinity' }
    @{ Name = 'a number as a string'; Value = '5'; Expected = '"5"' }
    @{ Name = 'a boolean'; Value = $true; Expected = 'true' }
    @{ Name = 'an empty array'; Value = @(); Expected = '[]' }
    @{ Name = 'one element holding a space'; Value = @('a b'); Expected = '["a b"]' }
    @{ Name = 'two elements'; Value = @('a', 'b'); Expected = '["a","b"]' }
    @{ Name = 'nested arrays'; Value = @(, @(1, 2)); Expected = '[[1,2]]' }
    @{ Name = 'a hashtable'; Value = @{ a = 1 }; Expected = '[Hashtable] {"a":1}' }
    @{ Name = 'an ordered dictionary'; Value = [ordered]@{ a = 1 }; Expected = '[OrderedDictionary] {"a":1}' }
    @{ Name = 'an object'; Value = [PSCustomObject]@{ a = 1 }; Expected = '[PSCustomObject] {"a":1}' }
    @{ Name = 'a char'; Value = [char]'a'; Expected = '[Char] a' }
    @{ Name = 'a pointer'; Value = [IntPtr]1; Expected = '[IntPtr] 1' }
    @{ Name = 'big integers in a list'; Value = @([bigint]5, [bigint]-7); Expected = '[5,-7]' }
    @{ Name = '128-bit integers in a list'; Value = @([Int128]5, [UInt128]6); Expected = '[5,6]' }
    @{ Name = 'a half in a list'; Value = @([Half]1.5); Expected = '[1.5]' }
    @{ Name = 'a pointer in a hashtable'; Value = @{ a = [IntPtr]1 }; Expected = '[Hashtable] {"a":1}' }
    @{
        Name = 'an unsigned pointer in an object'
        Value = [PSCustomObject]@{ a = [UIntPtr]2 }
        Expected = '[PSCustomObject] {"a":2}'
    }
    @{
        Name = 'an object deeper than JSON is written'
        Value = [PSCustomObject]@{ l1 = [PSCustomObject]@{ l2 = [PSCustomObject]@{ l3 = [PSCustomObject]@{ l4 = [PSCustomObject]@{ l5 = [PSCustomObject]@{ v = 1 } } } } } }
        Expected = '[PSCustomObject] {"l1":{"l2":{"l3":{"l4":{"l5":"@{v=1}"}}}}}'
    }
    @{
        Name = 'a big integer too large for a long, nested'
        Value = @(, @([bigint]::Pow(10, 30)))
        Expected = '[["1000000000000000000000000000000"]]'
    }
    @{ Name = 'a boolean a cmdlet returned'; Value = $exists; Expected = 'true' }
    @{
        Name = 'a date, to the tick'
        Value = [DateTime]::new(2026, 1, 2, 3, 4, 5, 6, [DateTimeKind]::Utc)
        Expected = '[DateTime] 2026-01-02T03:04:05.0060000Z'
    }
    @{
        Name = 'a date with an offset'
        Value = [DateTimeOffset]::new(2026, 1, 2, 3, 4, 5, [TimeSpan]::FromHours(2))
        Expected = '[DateTimeOffset] 2026-01-02T03:04:05.0000000+02:00'
    }
    @{ Name = 'an XML document'; Value = [xml]'<a x="1"><b /></a>'; Expected = '[XmlDocument] <a x="1"><b /></a>' }
    @{ Name = 'a string of any length'; Value = 'x' * 1000; Expected = '"' + 'x' * 1000 + '"' }
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - each kind of value, as a failure message would show it
foreach ($case in $cases) {
    $text = & $module { param($Value) Get-TestValueText -Value $Value } $case.Value
    Assert-Equal -Expected $case.Expected -Actual $text -Message "Rendering $($case.Name)"
}

$comparedCases = @(
    @{ Name = 'a float compared with a double'; Value = [float]0.1; Other = 0.1; Expected = '[Single] 0.1' }
    @{ Name = 'a double compared with a float'; Value = 0.1; Other = [float]0.1; Expected = '[Double] 0.1' }
    @{ Name = 'a double compared with an int'; Value = 3.0; Other = 4; Expected = '[Double] 3' }
    @{ Name = 'an int compared with a double'; Value = 4; Other = 3.0; Expected = '[Int32] 4' }
    @{ Name = 'a double compared with a double'; Value = 0.1; Other = 0.2; Expected = '0.1' }
    @{ Name = 'a double compared with a string'; Value = 0.1; Other = '0.1'; Expected = '0.1' }
    @{ Name = 'an int compared with a long'; Value = 4; Other = [long]5; Expected = '4' }
    @{ Name = 'a double compared with $null'; Value = 0.1; Other = $null; Expected = '0.1' }
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a number beside the one it was compared with
foreach ($case in $comparedCases) {
    $text = & $module { param($Value, $Other) Get-TestValueText -Value $Value -Other $Other } $case.Value $case.Other
    Assert-Equal -Expected $case.Expected -Actual $text -Message "Rendering $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value with no natural JSON form
$info = [FileInfo]::new((Join-Path ([Path]::GetTempPath()) 'file.txt'))

# Act
$text = & $module { param($Value) Get-TestValueText -Value $Value } $info

# Assert
Assert-That -Condition ($text.StartsWith('[FileInfo] ') -and $text.EndsWith('file.txt')) `
    -Message 'An object with no JSON form is its type and its text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that throws when anything tries to enumerate it
# A C# type, not a PowerShell class: the coverage tracer cannot follow a
# class method that throws, and crashes the whole file instead.
Add-Type -TypeDefinition @"
using System;
using System.Collections;
public class Unenumerable : IEnumerable
{
    public IEnumerator GetEnumerator()
    {
        throw new InvalidOperationException("cannot enumerate");
    }
}
"@

# Act
$text = & $module { param($Value) Get-TestValueText -Value $Value } ([Unenumerable]::new())

# Assert
Assert-Equal -Expected '[Unenumerable]' -Actual $text `
    -Message 'Describing a value that cannot be described falls back to its type, and never throws'

exit (Complete-TestRun)
