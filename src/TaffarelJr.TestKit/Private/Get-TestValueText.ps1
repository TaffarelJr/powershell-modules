using namespace System.Collections
using namespace System.Globalization
using namespace System.Xml

function Get-TestValueText {
    <#
    .SYNOPSIS
        Returns the whole text a failure message shows for a value.
    .DESCRIPTION
        Not exported. Values with a natural JSON form are rendered as JSON,
        which keeps the things interpolation hides apart: "a b" is not
        "a","b", null is not "", and 1 is not "1". A dictionary or an object
        is prefixed with its type, since a hashtable and a PSCustomObject of
        the same content render alike as JSON. A float or a double is shown
        as its shortest round-trip text, a date to the tick, an XML node as
        its markup, and anything else as its type and its text.
    .PARAMETER Value
        The value to render.
    .PARAMETER Other
        The value it was compared with, if any. A float or a double shows its
        shortest round-trip text, so it is prefixed with its type when the
        other value is a number of another type: a [float] 0.1 and a
        [double] 0.1 differ, but print alike. The other number is prefixed
        the same way.
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value,

        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Other
    )

    $Value = Get-BaseValue $Value
    if ($null -eq $Value) {
        return 'null'
    }

    $type = $Value.GetType()
    if ($Value -is [DateTime] -or $Value -is [DateTimeOffset]) {
        return "[$($type.Name)] $($Value.ToString('o', [CultureInfo]::InvariantCulture))"
    }

    if ($Value -is [XmlNode]) {
        return "[$($type.Name)] $($Value.OuterXml)"
    }

    $Other = Get-BaseValue $Other
    $isFloat = $Value -is [double] -or $Value -is [float]
    $otherIsFloat = $Other -is [double] -or $Other -is [float]
    $typePrefix = ''
    $numbersOfTwoTypes = (Test-NumberType -Value $Value) -and
        (Test-NumberType -Value $Other) -and
        $Other.GetType() -ne $type
    if ($numbersOfTwoTypes -and ($isFloat -or $otherIsFloat)) {
        $typePrefix = "[$($type.Name)] "
    }

    if ($isFloat) {
        return $typePrefix + $Value.ToString('R', [CultureInfo]::InvariantCulture)
    }

    $isNumber = (Test-NumberType -Value $Value) -or $Value -is [bool]
    $isContainer = $Value -is [IDictionary] -or $Value -is [pscustomobject]
    $hasJsonForm = $isNumber -or $isContainer -or $Value -is [string] -or $Value -is [IEnumerable]
    if ($hasJsonForm) {
        try {
            $writable = ConvertTo-TestJsonValue -Value $Value
            $json = ConvertTo-Json -InputObject $writable -Compress -Depth 4 -WarningAction SilentlyContinue
            if ($isContainer) {
                return "[$($type.Name)] $json"
            }

            return $typePrefix + $json
        }
        catch {
            # Fall through to the type and text below.
            $null = $_
        }
    }

    # Describing a value must never throw, or the failure it was meant to
    # explain is lost behind this one.
    try {
        return "[$($type.Name)] $Value"
    }
    catch {
        return "[$($type.Name)]"
    }
}
