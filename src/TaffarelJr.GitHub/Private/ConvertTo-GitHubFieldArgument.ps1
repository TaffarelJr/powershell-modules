using namespace System.Collections.Generic

function ConvertTo-GitHubFieldArgument {
    <#
    .SYNOPSIS
        Turns a hashtable of request parameters into gh api's repeated
        flag/value argument pairs.
    .DESCRIPTION
        Not exported. Keys are emitted in sorted order so the argument
        vector is deterministic. An array value becomes one key[]=value
        pair per element (an empty array becomes a bare key[], gh's syntax
        for an empty list); $null becomes null and a bool becomes true or
        false in lower case, which gh's -F typing turns back into JSON
        null and booleans.
    .PARAMETER Flag
        The gh flag repeated before every pair: '--field' or
        '--raw-field'.
    .PARAMETER Fields
        The parameters, keyed by name. May be $null for none.
    .OUTPUTS
        Alternating flag and key=value strings, always an array - empty
        when there are no fields.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Flag,

        [hashtable]$Fields
    )

    $format = {
        param($Value)

        if ($null -eq $Value) {
            return 'null'
        }

        if ($Value -is [bool]) {
            return $Value.ToString().ToLowerInvariant()
        }

        return [string]$Value
    }

    $arguments = [List[string]]::new()
    if ($null -eq $Fields) {
        return , $arguments.ToArray()
    }

    foreach ($key in ($Fields.Keys | Sort-Object)) {
        $value = $Fields[$key]
        if ($value -isnot [array]) {
            $arguments.Add($Flag)
            $arguments.Add("$key=$(& $format $value)")
            continue
        }

        if ($value.Count -eq 0) {
            $arguments.Add($Flag)
            $arguments.Add("$key[]")
        }

        foreach ($item in $value) {
            $arguments.Add($Flag)
            $arguments.Add("$key[]=$(& $format $item)")
        }
    }

    return , $arguments.ToArray()
}
