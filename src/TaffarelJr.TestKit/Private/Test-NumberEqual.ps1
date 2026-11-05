using namespace System.Globalization

function Test-NumberEqual {
    <#
    .SYNOPSIS
        Reports whether two numbers, of any numeric types, have the same
        value, exactly.
    .DESCRIPTION
        Not exported. PowerShell's -eq turns a long and a double both into
        doubles, so 9007199254740993 equals 9007199254740992.0, and NaN
        never equals NaN, so no test could expect it. Here:

        - integers, and an integer and a decimal, compare as decimals,
          which hold every integer type exactly;
        - an integer and a floating-point number are equal only if the
          floating-point number is whole and is exactly that integer;
        - two floating-point numbers compare as doubles, and NaN equals
          NaN;
        - a decimal matches a floating-point number only when it is the
          nearest one to it: [decimal]0.3 equals 0.3, but not 0.1 + 0.2,
          which -eq would round to the same decimal.
    .PARAMETER Expected
        The number the case requires.
    .PARAMETER Actual
        The number produced by the code under test.
    #>
    param(
        [Parameter(Mandatory)]
        $Expected,

        [Parameter(Mandatory)]
        $Actual
    )

    $expectedIsFloat = $Expected -is [double] -or $Expected -is [float]
    $actualIsFloat = $Actual -is [double] -or $Actual -is [float]
    if ($expectedIsFloat -and $actualIsFloat) {
        if ([double]::IsNaN($Expected) -and [double]::IsNaN($Actual)) {
            return $true
        }

        return [double]$Expected -eq [double]$Actual
    }

    if (-not ($expectedIsFloat -or $actualIsFloat)) {
        return [decimal]$Expected -eq [decimal]$Actual
    }

    $float = $Expected
    $other = $Actual
    if ($actualIsFloat) {
        $float = $Actual
        $other = $Expected
    }

    # Parsing the decimal's text rounds correctly; converting it with a cast
    # does not, and lands on the neighbor of the nearest double for many
    # decimals with more than 16 digits, such as [decimal]1 / 3.
    if ($other -is [decimal]) {
        $invariant = [CultureInfo]::InvariantCulture
        $text = $other.ToString($invariant)
        if ($float -is [float]) {
            return [float]::Parse($text, $invariant) -eq $float
        }

        return [double]::Parse($text, $invariant) -eq $float
    }

    $float = [double]$float
    if (-not [double]::IsFinite($float) -or [Math]::Floor($float) -ne $float) {
        return $false
    }

    return [bigint]::new($float) -eq [bigint]::new($other)
}
