using namespace System.Collections

function Assert-JsonValue {
    <#
    .SYNOPSIS
        Throws unless a setting's value is made only of things JSON can
        carry.
    .DESCRIPTION
        Not exported. ConvertTo-Json walks any object graph it is given: a
        FileInfo or a script block takes minutes, and past its depth limit a
        dictionary is written as its type name. Checking first turns either
        into an immediate error that names the setting, and where inside it
        the value sits.

        Allowed: $null, strings, chars, booleans, numbers other than NaN and
        the infinities, enums, DateTime values, lists, dictionaries whose
        keys are strings, and custom objects - what ConvertFrom-Json
        returns - whose properties are checked like a dictionary's entries.
        Lists, dictionaries, and objects may nest up to 100 levels deep, as
        deep as the JSON written for them goes.
    .PARAMETER Key
        The setting's name, for the error message.
    .PARAMETER Value
        The value to check.
    .PARAMETER Path
        Where inside the setting Value sits, as .name and [index] steps;
        empty at the top level.
    .PARAMETER Depth
        How deep inside the setting Value sits; the top level is 0.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [string]$Path = '',

        [int]$Depth = 0
    )

    if ($null -eq $Value) {
        return
    }

    # Every type code from Boolean up is a scalar JSON can hold: booleans,
    # chars, the numeric types, DateTime and String. An enum reports its
    # underlying number's code.
    $code = [Type]::GetTypeCode($Value.GetType())
    if ($code -in [TypeCode]::Single, [TypeCode]::Double -and -not [double]::IsFinite($Value)) {
        throw "Setting '$Key$Path' is $Value, which JSON has no number for. Give a finite number instead."
    }

    if ($code -ge [TypeCode]::Boolean) {
        return
    }

    if ($Depth -gt 100) {
        throw "Setting '$Key' is nested more than 100 levels deep, which is more than a workspace file holds."
    }

    if ($Value -is [IDictionary]) {
        foreach ($name in $Value.PSBase.Keys) {
            if ($name -isnot [string]) {
                $keyType = $name.GetType().FullName
                throw "Setting '$Key$Path' has a dictionary key of type $keyType; JSON object keys are strings."
            }

            Assert-JsonValue -Key $Key -Value $Value[$name] -Path "$Path.$name" -Depth ($Depth + 1)
        }

        return
    }

    # Compared by type name, not with -is: any cmdlet output wrapped in a
    # PSObject answers true to -is [PSCustomObject], a FileInfo included.
    if ($Value.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
        foreach ($property in $Value.PSObject.Properties) {
            $name = $property.Name
            Assert-JsonValue -Key $Key -Value $property.Value -Path "$Path.$name" -Depth ($Depth + 1)
        }

        return
    }

    if ($Value -is [IList]) {
        for ($i = 0; $i -lt $Value.Count; $i++) {
            Assert-JsonValue -Key $Key -Value $Value[$i] -Path "$Path[$i]" -Depth ($Depth + 1)
        }

        return
    }

    $type = $Value.GetType().FullName
    throw ("Setting '$Key$Path' has a value of type $type, which is not JSON. " +
        'Give it a string, number, boolean, list, dictionary, or custom object instead.')
}
