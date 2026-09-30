#Requires -Version 7.4
using namespace System.Collections.Generic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

enum Color {
    Red
    Blue
}

$exists = Test-Path -LiteralPath $PSScriptRoot
$wrappedNumbers = @(3, 1).ForEach({ $_ })
$guid = [Guid]::NewGuid()
$when = [DateTime]::new(2026, 10, 12)
$genericLower = [Dictionary[string, object]]::new()
$genericLower['a'] = 1
$genericUpper = [Dictionary[string, object]]::new()
$genericUpper['A'] = 1
$genericOther = [Dictionary[string, object]]::new()
$genericOther['a'] = 2
$selfFirst = @{ name = 'same' }
$selfFirst.self = $selfFirst
$selfSecond = @{ name = 'same' }
$selfSecond.self = $selfSecond
$selfOther = @{ name = 'other' }
$selfOther.self = $selfOther
$selfListFirst = [List[object]]::new()
$selfListFirst.Add($selfListFirst)
$selfListSecond = [List[object]]::new()
$selfListSecond.Add($selfListSecond)
$selfListLonger = [List[object]]::new()
$selfListLonger.Add($selfListLonger)
$selfListLonger.Add(1)
$xml = [xml]'<a x="1"><b /></a>'
$cases = @(
    @{ Name = 'equal strings'; Expected = 'a'; Actual = 'a'; Equal = $true }
    @{ Name = 'strings differing only in case'; Expected = 'Abc'; Actual = 'abc'; Equal = $false }
    @{
        Name     = 'a string and the same with a leading byte order mark'
        Expected = 'x'
        Actual   = "`u{FEFF}x"
        Equal    = $false
    }
    @{
        Name     = 'a string and the same with a soft hyphen inside'
        Expected = 'xy'
        Actual   = "x`u{00AD}y"
        Equal    = $false
    }
    @{ Name = 'two empty strings'; Expected = ''; Actual = ''; Equal = $true }
    @{ Name = 'an empty string and $null'; Expected = ''; Actual = $null; Equal = $false }
    @{ Name = 'a string and a number'; Expected = '5'; Actual = 5; Equal = $false }
    @{ Name = 'a number and an empty string'; Expected = 0; Actual = ''; Equal = $false }
    @{ Name = 'a string and a boolean'; Expected = $true; Actual = 'true'; Equal = $false }
    @{ Name = 'a char and a one-character string'; Expected = [char]'a'; Actual = 'a'; Equal = $false }
    @{ Name = 'two $null'; Expected = $null; Actual = $null; Equal = $true }
    @{ Name = '$null and zero'; Expected = $null; Actual = 0; Equal = $false }
    @{ Name = 'zero and $null'; Expected = 0; Actual = $null; Equal = $false }
    @{ Name = '$null and an empty array'; Expected = $null; Actual = @(); Equal = $false }
    @{ Name = 'an empty array and $null'; Expected = @(); Actual = $null; Equal = $false }
    @{ Name = 'equal ints'; Expected = 5; Actual = 5; Equal = $true }
    @{ Name = 'an int and a long of the same value'; Expected = 5; Actual = [long]5; Equal = $true }
    @{ Name = 'an int and a double of the same value'; Expected = 5; Actual = 5.0; Equal = $true }
    @{ Name = 'a decimal and a double of the same value'; Expected = [decimal]1.5; Actual = 1.5; Equal = $true }
    @{ Name = 'different numbers'; Expected = 5; Actual = 6; Equal = $false }
    @{ Name = 'a boolean and a number'; Expected = $true; Actual = 1; Equal = $false }
    @{ Name = 'an int and a pointer of the same value'; Expected = 1; Actual = [IntPtr]1; Equal = $false }
    @{ Name = 'an unsigned pointer and an int of the same value'; Expected = [UIntPtr]1; Actual = 1; Equal = $false }
    @{ Name = 'equal pointers'; Expected = [IntPtr]1; Actual = [IntPtr]1; Equal = $true }
    @{ Name = 'different pointers'; Expected = [IntPtr]1; Actual = [IntPtr]2; Equal = $false }
    @{ Name = 'equal booleans'; Expected = $true; Actual = $true; Equal = $true }
    @{ Name = 'different booleans'; Expected = $true; Actual = $false; Equal = $false }
    @{ Name = 'equal arrays'; Expected = @(1, 2); Actual = @(1, 2); Equal = $true }
    @{ Name = 'the same elements in another order'; Expected = @(1, 2, 3); Actual = @(3, 2, 1); Equal = $false }
    @{ Name = 'repeats in different places'; Expected = @(1, 1, 2); Actual = @(1, 2, 2); Equal = $false }
    @{ Name = 'a longer array'; Expected = @(1, 2); Actual = @(1, 2, 3); Equal = $false }
    @{ Name = 'two empty arrays'; Expected = @(); Actual = @(); Equal = $true }
    @{ Name = 'arrays differing only in case'; Expected = @('a'); Actual = @('A'); Equal = $false }
    @{ Name = 'arrays of numbers and strings'; Expected = @(1, 2); Actual = @('1', '2'); Equal = $false }
    @{ Name = 'arrays holding $null'; Expected = @($null, 1); Actual = @($null, 1); Equal = $true }
    @{ Name = '$null in one array and a value in the other'; Expected = @(1, $null); Actual = @(1, 2); Equal = $false }
    @{ Name = 'equal nested arrays'; Expected = @(, @(1, 2)); Actual = @(, @(1, 2)); Equal = $true }
    @{ Name = 'different nested arrays'; Expected = @(, @(1, 2)); Actual = @(, @(3, 4)); Equal = $false }
    @{
        Name = 'a byte array and an int array of the same values'
        Expected = [byte[]]@(1, 2)
        Actual = @(1, 2)
        Equal = $true
    }
    @{
        Name = 'a list and an array of the same values'
        Expected = [List[string]]@('a')
        Actual = @('a')
        Equal = $true
    }
    @{ Name = 'a one-element array and its element'; Expected = @('a'); Actual = 'a'; Equal = $false }
    @{ Name = 'an element and a one-element array of it'; Expected = 'a'; Actual = @('a'); Equal = $false }
    @{ Name = 'a one-element array of a number and the number'; Expected = @(1); Actual = 1; Equal = $false }
    @{ Name = 'a number and a one-element array of it'; Expected = 1; Actual = @(1); Equal = $false }
    @{ Name = 'an object and a number'; Expected = [PSCustomObject]@{ a = 1 }; Actual = 5; Equal = $false }
    @{ Name = 'a number and an object'; Expected = 5; Actual = [PSCustomObject]@{ a = 1 }; Equal = $false }
    @{ Name = 'equal hashtables'; Expected = @{ a = 1 }; Actual = @{ a = 1 }; Equal = $true }
    @{ Name = 'hashtables with different values'; Expected = @{ a = 1 }; Actual = @{ a = 2 }; Equal = $false }
    @{
        Name = 'hashtable values differing only in case'
        Expected = @{ a = 'X' }
        Actual = @{ a = 'x' }
        Equal = $false
    }
    @{ Name = 'hashtables with different keys'; Expected = @{ a = 1 }; Actual = @{ b = 1 }; Equal = $false }
    @{ Name = 'a hashtable with an extra key'; Expected = @{ a = 1 }; Actual = @{ a = 1; b = 2 }; Equal = $false }
    @{
        Name = 'a hashtable with a key named Count and one with an extra key'
        Expected = @{ Count = 1 }
        Actual = @{ Count = 1; b = 2 }
        Equal = $false
    }
    @{
        Name = 'an ordered dictionary with a key named Count and one with an extra key'
        Expected = [ordered]@{ Count = 1 }
        Actual = [ordered]@{ Count = 1; b = 2 }
        Equal = $false
    }
    @{
        Name = 'equal nested hashtables'
        Expected = @{ a = @{ b = @(1) } }
        Actual = @{ a = @{ b = @(1) } }
        Equal = $true
    }
    @{
        Name = 'an ordered dictionary and a hashtable of the same content'
        Expected = [ordered]@{ a = 1 }
        Actual = @{ a = 1 }
        Equal = $true
    }
    @{
        Name = 'a hashtable and an object with the same members'
        Expected = @{ a = 1 }
        Actual = [PSCustomObject]@{ a = 1 }
        Equal = $false
    }
    @{
        Name = 'equal objects'
        Expected = [PSCustomObject]@{ a = 1 }
        Actual = [PSCustomObject]@{ a = 1 }
        Equal = $true
    }
    @{
        Name = 'objects with different values'
        Expected = [PSCustomObject]@{ a = 1 }
        Actual = [PSCustomObject]@{ a = 2 }
        Equal = $false
    }
    @{
        Name = 'objects with different property names'
        Expected = [PSCustomObject]@{ a = 1 }
        Actual = [PSCustomObject]@{ b = 1 }
        Equal = $false
    }
    @{
        Name = 'an object with an extra property'
        Expected = [PSCustomObject]@{ a = 1 }
        Actual = [PSCustomObject]@{ a = 1; b = 2 }
        Equal = $false
    }
    @{
        Name = 'equal objects with a property named Count'
        Expected = [PSCustomObject]@{ Name = 'a'; Count = 3 }
        Actual = [PSCustomObject]@{ Name = 'a'; Count = 3 }
        Equal = $true
    }
    @{
        Name = 'an object with a property named Count and one with an extra property'
        Expected = [PSCustomObject]@{ Count = 1 }
        Actual = [PSCustomObject]@{ Count = 1; b = 2 }
        Equal = $false
    }
    @{
        Name = 'equal nested objects'
        Expected = [PSCustomObject]@{ a = [PSCustomObject]@{ b = 1 } }
        Actual = [PSCustomObject]@{ a = [PSCustomObject]@{ b = 1 } }
        Equal = $true
    }
    @{ Name = 'an object and a string'; Expected = [PSCustomObject]@{ a = 1 }; Actual = '@{a=1}'; Equal = $false }
    @{ Name = 'equal guids'; Expected = $guid; Actual = [Guid]::Parse($guid.ToString()); Equal = $true }
    @{ Name = 'equal dates'; Expected = $when; Actual = [DateTime]::new(2026, 10, 12); Equal = $true }
    @{ Name = 'different dates'; Expected = $when; Actual = $when.AddDays(1); Equal = $false }
    @{ Name = 'equal enum values'; Expected = [Color]::Red; Actual = [Color]::Red; Equal = $true }
    @{ Name = 'different enum values'; Expected = [Color]::Red; Actual = [Color]::Blue; Equal = $false }
    @{ Name = 'an enum value and its number'; Expected = [Color]::Blue; Actual = 1; Equal = $false }
    @{ Name = 'a date and a string'; Expected = $when; Actual = $when.ToString(); Equal = $false }
    @{ Name = 'a cmdlet-wrapped boolean and a plain one'; Expected = $true; Actual = $exists; Equal = $true }
    @{ Name = 'a cmdlet-wrapped boolean and a string'; Expected = 'True'; Actual = $exists; Equal = $false }
    @{ Name = 'wrapped numbers and a plain array of them'; Expected = @(3, 1); Actual = $wrappedNumbers; Equal = $true }
    @{ Name = 'wrapped numbers and different plain ones'; Expected = @(3, 2); Actual = $wrappedNumbers; Equal = $false }
    @{
        Name = 'wrapped values inside a hashtable'
        Expected = @{ found = $true }
        Actual = @{ found = $exists }
        Equal = $true
    }
    @{ Name = 'hashtable keys differing only in case'; Expected = @{ a = 1 }; Actual = @{ A = 1 }; Equal = $false }
    @{
        Name = 'ordered dictionary keys differing only in case'
        Expected = [ordered]@{ a = 1 }
        Actual = [ordered]@{ A = 1 }
        Equal = $false
    }
    @{
        Name = 'nested hashtable keys differing only in case'
        Expected = @{ a = @{ b = 1 } }
        Actual = @{ a = @{ B = 1 } }
        Equal = $false
    }
    @{ Name = 'a string key and a number key'; Expected = @{ '1' = 'x' }; Actual = @{ 1 = 'x' }; Equal = $false }
    @{
        Name = 'a hashtable and a generic dictionary of the same content'
        Expected = @{ a = 1 }
        Actual = $genericLower
        Equal = $true
    }
    @{
        Name = 'a generic dictionary and a hashtable of the same content'
        Expected = $genericLower
        Actual = @{ a = 1 }
        Equal = $true
    }
    @{
        Name = 'a hashtable and a generic dictionary with a different value'
        Expected = @{ a = 1 }
        Actual = $genericOther
        Equal = $false
    }
    @{
        Name = 'a hashtable and a generic dictionary with a key in another case'
        Expected = @{ a = 1 }
        Actual = $genericUpper
        Equal = $false
    }
    @{
        Name = 'object property names differing only in case'
        Expected = [PSCustomObject]@{ name = 1 }
        Actual = [PSCustomObject]@{ Name = 1 }
        Equal = $false
    }
    @{
        Name = 'nested object property names differing only in case'
        Expected = [PSCustomObject]@{ a = [PSCustomObject]@{ b = 1 } }
        Actual = [PSCustomObject]@{ a = [PSCustomObject]@{ B = 1 } }
        Equal = $false
    }
    @{
        Name = 'two hashtables that contain themselves alike'
        Expected = $selfFirst
        Actual = $selfSecond
        Equal = $true
    }
    @{
        Name = 'two hashtables that contain themselves, differing elsewhere'
        Expected = $selfFirst
        Actual = $selfOther
        Equal = $false
    }
    @{
        Name = 'two one-element lists that each hold only themselves'
        Expected = $selfListFirst
        Actual = $selfListSecond
        Equal = $true
    }
    @{
        Name = 'a list that holds only itself and one that holds itself and more'
        Expected = $selfListFirst
        Actual = $selfListLonger
        Equal = $false
    }
    @{ Name = 'equal XML documents'; Expected = $xml; Actual = [xml]'<a x="1"><b /></a>'; Equal = $true }
    @{
        Name = 'XML documents differing in an attribute'
        Expected = $xml
        Actual = [xml]'<a x="2"><b /></a>'
        Equal = $false
    }
    @{
        Name = 'XML documents differing only in case'
        Expected = $xml
        Actual = [xml]'<A x="1"><b /></A>'
        Equal = $false
    }
    @{
        Name = 'equal XML elements'
        Expected = $xml.DocumentElement
        Actual = ([xml]'<a x="1"><b /></a>').DocumentElement
        Equal = $true
    }
    @{
        Name = 'an XML document and its own root element'
        Expected = $xml
        Actual = $xml.DocumentElement
        Equal = $false
    }
    @{ Name = 'an XML document and its text'; Expected = $xml; Actual = $xml.OuterXml; Equal = $false }
    @{
        Name = 'an XML element and an array holding it'
        Expected = $xml.DocumentElement
        Actual = @($xml.DocumentElement, 1)
        Equal = $false
    }
    @{
        Name = 'a long and a double that rounds to it'
        Expected = [long]9007199254740993
        Actual = [double]9007199254740992
        Equal = $false
    }
    @{ Name = 'NaN and NaN'; Expected = [double]::NaN; Actual = [double]::NaN; Equal = $true }
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every pairing in the table
# Judged by plain comparison, not by Assert-Equal, which is this function
foreach ($case in $cases) {
    $result = & $module { param($Expected, $Actual) Test-ValueEqual -Expected $Expected -Actual $Actual } `
        $case.Expected $case.Actual
    Assert-That -Condition ($result -is [bool] -and $result -eq $case.Equal) `
        -Message "Equality of $($case.Name) is $($case.Equal) (got $result)"
}

exit (Complete-TestRun)
