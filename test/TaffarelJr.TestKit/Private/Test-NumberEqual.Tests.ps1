#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

$cases = @(
    @{ Name = 'equal ints'; Expected = 5; Actual = 5; Equal = $true }
    @{ Name = 'different ints'; Expected = 5; Actual = 6; Equal = $false }
    @{ Name = 'an int and a long of the same value'; Expected = 5; Actual = [long]5; Equal = $true }
    @{
        Name = 'a long and an unsigned long one apart, near the top'
        Expected = [long]::MaxValue
        Actual = [ulong]9223372036854775806
        Equal = $false
    }
    @{
        Name = 'a long and an unsigned long of the same large value'
        Expected = [long]::MaxValue
        Actual = [ulong][long]::MaxValue
        Equal = $true
    }
    @{ Name = 'a byte and a negative int'; Expected = [byte]255; Actual = -1; Equal = $false }
    @{ Name = 'an int and a double of the same value'; Expected = 5; Actual = 5.0; Equal = $true }
    @{ Name = 'an int and a double with a fraction'; Expected = 5; Actual = 5.5; Equal = $false }
    @{ Name = 'a double and an int of the same value'; Expected = 5.0; Actual = 5; Equal = $true }
    @{
        Name = 'a long and a double that rounds to it'
        Expected = [long]9007199254740993
        Actual = [double]9007199254740992
        Equal = $false
    }
    @{
        Name = 'a long and the double it is exactly'
        Expected = [long]9007199254740992
        Actual = [double]9007199254740992
        Equal = $true
    }
    @{
        Name = 'the largest long less one and the largest long as a double'
        Expected = [long]::MaxValue - 1
        Actual = [double][long]::MaxValue
        Equal = $false
    }
    @{
        Name = 'the largest unsigned long and its nearest double'
        Expected = [ulong]::MaxValue
        Actual = [double][ulong]::MaxValue
        Equal = $false
    }
    @{ Name = 'an int and infinity'; Expected = 5; Actual = [double]::PositiveInfinity; Equal = $false }
    @{ Name = 'an int and NaN'; Expected = 0; Actual = [double]::NaN; Equal = $false }
    @{ Name = 'NaN and NaN'; Expected = [double]::NaN; Actual = [double]::NaN; Equal = $true }
    @{ Name = 'a single NaN and a double NaN'; Expected = [single]::NaN; Actual = [double]::NaN; Equal = $true }
    @{ Name = 'NaN and zero'; Expected = [double]::NaN; Actual = 0.0; Equal = $false }
    @{
        Name = 'equal infinities'
        Expected = [double]::PositiveInfinity
        Actual = [single]::PositiveInfinity
        Equal = $true
    }
    @{ Name = 'different doubles'; Expected = 1.5; Actual = 2.5; Equal = $false }
    @{ Name = 'a decimal and an int of the same value'; Expected = [decimal]5; Actual = 5; Equal = $true }
    @{ Name = 'a decimal with a fraction and an int'; Expected = [decimal]5.25; Actual = 5; Equal = $false }
    @{ Name = 'a decimal and a double of the same value'; Expected = [decimal]1.5; Actual = 1.5; Equal = $true }
    @{ Name = 'a decimal and a different double'; Expected = [decimal]1.5; Actual = 1.25; Equal = $false }
    @{ Name = 'a decimal and the double nearest to it'; Expected = [decimal]0.3; Actual = 0.3; Equal = $true }
    @{ Name = 'a decimal and a double that rounds to it'; Expected = [decimal]0.3; Actual = 0.1 + 0.2; Equal = $false }
    @{
        Name = 'a double that rounds to a decimal, and the decimal'
        Expected = 0.1 + 0.2
        Actual = [decimal]0.3
        Equal = $false
    }
    @{ Name = 'a whole decimal and a double just above it'; Expected = [decimal]1; Actual = 1 + 1e-15; Equal = $false }
    @{ Name = 'a decimal and the float nearest to it'; Expected = [decimal]0.1; Actual = [float]0.1; Equal = $true }
    @{ Name = 'a float and the decimal it is nearest to'; Expected = [float]0.1; Actual = [decimal]0.1; Equal = $true }
    @{
        Name = 'a decimal and a float widened to a double'
        Expected = [decimal]0.1
        Actual = [double][float]0.1
        Equal = $false
    }
    @{ Name = 'a decimal and a different float'; Expected = [decimal]0.1; Actual = [float]0.2; Equal = $false }
    @{ Name = 'a decimal and NaN'; Expected = [decimal]0; Actual = [double]::NaN; Equal = $false }
    @{ Name = 'a third as a decimal and as a double'; Expected = [decimal]1 / 3; Actual = 1 / 3; Equal = $true }
    @{ Name = 'a third as a double and as a decimal'; Expected = 1 / 3; Actual = [decimal]1 / 3; Equal = $true }
    @{
        Name = 'a third as a decimal and the double next to the nearest'
        Expected = [decimal]1 / 3
        Actual = 0.33333333333333337
        Equal = $false
    }
    @{
        Name = 'the double next to the nearest and a third as a decimal'
        Expected = 0.33333333333333337
        Actual = [decimal]1 / 3
        Equal = $false
    }
    @{ Name = 'two thirds as a decimal and as a double'; Expected = [decimal]2 / 3; Actual = 2 / 3; Equal = $true }
    @{ Name = 'a seventh as a decimal and as a double'; Expected = [decimal]1 / 7; Actual = 1 / 7; Equal = $true }
    @{
        Name = 'a seventh as a decimal and as a float'
        Expected = [decimal]1 / 7
        Actual = [float](1 / 7)
        Equal = $true
    }
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every pairing in the table
foreach ($case in $cases) {
    $result = & $module { param($Expected, $Actual) Test-NumberEqual -Expected $Expected -Actual $Actual } $case.Expected $case.Actual
    Assert-That -Condition ($result -is [bool] -and $result -eq $case.Equal) `
        -Message "Equality of $($case.Name) is $($case.Equal) (got $result)"
}

exit (Complete-TestRun)
