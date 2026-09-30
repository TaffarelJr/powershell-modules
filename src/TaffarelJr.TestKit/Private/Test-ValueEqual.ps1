using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Xml

function Test-ValueEqual {
    <#
    .SYNOPSIS
        Reports whether two values are equal, strictly.
    .DESCRIPTION
        Not exported. Strict where PowerShell's own -eq is forgiving, since
        a test that cannot tell 'Abc' from 'abc', or 0 from '', cannot catch
        the regression it exists for:

        - strings compare code point by code point (PowerShell's own -ceq
          follows culture rules, under which a byte order mark or a soft
          hyphen counts for nothing), and never equal a number or a boolean;
        - $null equals only $null;
        - an array (or list) equals only another, of the same length, with
          equal elements in the same order;
        - a dictionary equals only a dictionary with the same keys and
          equal values; keys compare exactly, so 'a' is not 'A' and '1' is
          not 1;
        - a PSCustomObject equals only one with the same property names,
          compared case-sensitively, and equal values;
        - numbers compare by value whatever their types, exactly (see
          Test-NumberEqual); a pointer ([IntPtr], [UIntPtr]) is not a
          number;
        - an XML node equals only a node of the same type with the same
          markup;
        - anything else must be the same type and Equals.

        Nested values are compared the same way. A value that contains
        itself is compared once, not forever.
    .PARAMETER Expected
        The value the case requires.
    .PARAMETER Actual
        The value produced by the code under test.
    .PARAMETER Comparing
        The pairs already being compared further up the recursion. Callers
        leave it out.
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Expected,

        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Actual,

        [List[object]]$Comparing = [List[object]]::new()
    )

    $Expected = Get-BaseValue $Expected
    $Actual = Get-BaseValue $Actual

    if ($null -eq $Expected -or $null -eq $Actual) {
        return ($null -eq $Expected) -and ($null -eq $Actual)
    }

    $expectedIsString = $Expected -is [string]
    $actualIsString = $Actual -is [string]
    if ($expectedIsString -or $actualIsString) {
        return $expectedIsString -and $actualIsString -and
        [string]::Equals($Expected, $Actual, [StringComparison]::Ordinal)
    }

    # Meeting a pair again means a value contains itself; its contents are
    # already being compared further up.
    foreach ($pair in $Comparing) {
        if ([object]::ReferenceEquals($pair[0], $Expected) -and [object]::ReferenceEquals($pair[1], $Actual)) {
            return $true
        }
    }

    $Comparing.Add(@($Expected, $Actual))
    try {
        $expectedIsDictionary = $Expected -is [IDictionary]
        $actualIsDictionary = $Actual -is [IDictionary]
        if ($expectedIsDictionary -or $actualIsDictionary) {
            if (-not ($expectedIsDictionary -and $actualIsDictionary)) {
                return $false
            }

            # PSBase: a dictionary's key named Count would otherwise be read
            # in place of its count.
            if ($Expected.PSBase.Count -ne $Actual.PSBase.Count) {
                return $false
            }

            # The default comparer is ordinal for strings and never equates
            # keys of different types, whatever the dictionary's own
            # comparer forgives.
            $actualEntries = [Dictionary[object, object]]::new()
            foreach ($entry in $Actual.GetEnumerator()) {
                $actualEntries[(Get-BaseValue $entry.Key)] = $entry.Value
            }

            foreach ($entry in $Expected.GetEnumerator()) {
                $key = Get-BaseValue $entry.Key
                if (-not $actualEntries.ContainsKey($key)) {
                    return $false
                }

                $equal = Test-ValueEqual -Expected $entry.Value -Actual $actualEntries[$key] -Comparing $Comparing
                if (-not $equal) {
                    return $false
                }
            }

            return $true
        }

        $left = $null
        if ($Expected -is [IEnumerable]) {
            $left = @($Expected)
        }

        $right = $null
        if ($Actual -is [IEnumerable]) {
            $right = @($Actual)
        }

        # @() wraps a value it does not enumerate, such as an XML node, as
        # itself; comparing that "list" would compare the same pair forever. A
        # real list whose one element is itself looks the same from outside,
        # so a list type is always a list, and the cycle guard above ends it.
        $expectedIsList = $null -ne $left -and ($Expected -is [IList] -or
            -not ($left.Count -eq 1 -and [object]::ReferenceEquals($left[0], $Expected)))
        $actualIsList = $null -ne $right -and ($Actual -is [IList] -or
            -not ($right.Count -eq 1 -and [object]::ReferenceEquals($right[0], $Actual)))
        if ($expectedIsList -or $actualIsList) {
            if (-not ($expectedIsList -and $actualIsList)) {
                return $false
            }

            if ($left.Count -ne $right.Count) {
                return $false
            }

            for ($i = 0; $i -lt $left.Count; $i++) {
                if (-not (Test-ValueEqual -Expected $left[$i] -Actual $right[$i] -Comparing $Comparing)) {
                    return $false
                }
            }

            return $true
        }

        $expectedIsObject = $Expected -is [pscustomobject]
        $actualIsObject = $Actual -is [pscustomobject]
        if ($expectedIsObject -or $actualIsObject) {
            if (-not ($expectedIsObject -and $actualIsObject)) {
                return $false
            }

            # PSObject.Properties looks a name up case-insensitively.
            $rightProperties = [Dictionary[string, object]]::new([StringComparer]::Ordinal)
            foreach ($property in $Actual.psobject.Properties) {
                $rightProperties[$property.Name] = $property.Value
            }

            $leftProperties = @($Expected.psobject.Properties)

            # PSBase, as for the dictionaries above: a property named Count
            # would be read in place of the count.
            if ($leftProperties.Count -ne $rightProperties.PSBase.Count) {
                return $false
            }

            foreach ($property in $leftProperties) {
                if (-not $rightProperties.ContainsKey($property.Name)) {
                    return $false
                }

                $equal = Test-ValueEqual -Expected $property.Value `
                    -Actual $rightProperties[$property.Name] `
                    -Comparing $Comparing
                if (-not $equal) {
                    return $false
                }
            }

            return $true
        }

        $expectedIsNumber = Test-NumberType -Value $Expected
        $actualIsNumber = Test-NumberType -Value $Actual
        if ($expectedIsNumber -or $actualIsNumber) {
            return $expectedIsNumber -and $actualIsNumber -and (Test-NumberEqual -Expected $Expected -Actual $Actual)
        }

        if ($Expected.GetType() -ne $Actual.GetType()) {
            return $false
        }

        # A node's Equals is reference equality: two documents alike would
        # never be equal.
        if ($Expected -is [XmlNode]) {
            return [string]::Equals($Expected.OuterXml, $Actual.OuterXml, [StringComparison]::Ordinal)
        }

        return $Expected.Equals($Actual)
    }
    finally {
        $Comparing.RemoveAt($Comparing.Count - 1)
    }
}
