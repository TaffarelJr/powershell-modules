#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

$cases = @(
    @{ Name = '$null'; Value = $null; Expected = $null }
    @{ Name = 'a string'; Value = 'a'; Expected = 'a' }
    @{ Name = 'an int'; Value = 5; Expected = 5 }
    @{ Name = 'a half'; Value = [Half]1.5; Expected = [double]1.5 }
    @{ Name = 'a pointer'; Value = [IntPtr]-1; Expected = [long]-1 }
    @{ Name = 'an unsigned pointer'; Value = [UIntPtr]2; Expected = [ulong]2 }
    @{ Name = 'a big integer'; Value = [bigint]-5; Expected = [long]-5 }
    @{ Name = 'a 128-bit integer above a long'; Value = [Int128][ulong]::MaxValue; Expected = [ulong]::MaxValue }
    @{ Name = 'an unsigned 128-bit integer'; Value = [UInt128]6; Expected = [long]6 }
    @{
        Name = 'a big integer too large for a long'
        Value = [bigint]::Pow(10, 30)
        Expected = '1000000000000000000000000000000'
    }
    @{
        Name = 'a negative big integer too large for a long'
        Value = -[bigint]::Pow(10, 30)
        Expected = '-1000000000000000000000000000000'
    }
    @{ Name = 'a list'; Value = @([bigint]1, 'b'); Expected = @([long]1, 'b') }
    @{ Name = 'a hashtable'; Value = @{ a = [IntPtr]1 }; Expected = @{ a = [long]1 } }
    @{ Name = 'an object'; Value = [PSCustomObject]@{ a = [Half]0.5 }; Expected = @{ a = [double]0.5 } }
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every kind of value in the table
foreach ($case in $cases) {
    $converted = & $module { param($Value) ConvertTo-TestJsonValue -Value $Value } $case.Value
    Assert-Equal -Expected $case.Expected -Actual $converted -Message "Converting $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$generic = [Collections.Generic.Dictionary[object, object]]::new()
$generic[1] = 'one'
$generic['a'] = 'lower'
$generic['A'] = 'upper'

# Act
$copy = & $module { param($Value) ConvertTo-TestJsonValue -Value $Value } $generic

# Assert
Assert-Equal -Expected @(1, 'a', 'A') -Actual @($copy.PSBase.Keys) `
    -Message 'A dictionary keeps every key exactly, a number and keys differing only in case included'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$numbers = 1..100000
$plainTable = @{ a = 1; b = @('x', 2.5) }

# Act
$numbersBack = & $module { param($Value) ConvertTo-TestJsonValue -Value $Value } $numbers
$plainTableBack = & $module { param($Value) ConvertTo-TestJsonValue -Value $Value } $plainTable

# Assert
Assert-That -Condition ([object]::ReferenceEquals($numbers, $numbersBack)) `
    -Message 'A list holding nothing to convert comes back as itself, not copied'
Assert-That -Condition ([object]::ReferenceEquals($plainTable, $plainTableBack)) `
    -Message 'and so does a hashtable holding nothing to convert, however nested'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a big integer as deep as JSON writes a value, and a table one level deeper
$deepTable = @{ v = [bigint]5 }
$nested = @([bigint]0, @(1, @(2, @([bigint]4, $deepTable))))

# Act
$nestedBack = & $module { param($Value) ConvertTo-TestJsonValue -Value $Value } $nested
$innermost = $nestedBack[1][1][1]

# Assert
Assert-Equal -Expected 'System.Int64' -Actual $innermost[0].GetType().FullName `
    -Message 'A big integer as deep as JSON writes a value is converted'
Assert-That -Condition ([object]::ReferenceEquals($deepTable, $innermost[1])) `
    -Message 'but a container that deep comes back as itself, so JSON writes its own text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$self = @{}
$self.me = $self

# Act
$copy = & $module { param($Value) ConvertTo-TestJsonValue -Value $Value } $self

# Assert
Assert-That -Condition ($null -ne $copy) `
    -Message 'A hashtable that contains itself is copied only so deep, and the copy ends'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$xml = [xml]'<a><b /></a>'

# Act
$copy = & $module { param($Value) ConvertTo-TestJsonValue -Value $Value } $xml

# Assert
Assert-That -Condition ([object]::ReferenceEquals($xml, $copy)) `
    -Message 'An XML node is left as it is, not walked as a list'

exit (Complete-TestRun)
