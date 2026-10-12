using namespace System.Collections
using namespace System.Collections.Generic

function Add-GitHubFieldArgument {
    <#
    .SYNOPSIS
        Adds the flag/value pairs for one field, and for everything nested
        in it, to an argument list.
    .DESCRIPTION
        Not exported. The walk ConvertTo-GitHubFieldArgument runs over each
        top-level field. gh splits key=value at the first '=' and reads '['
        and ']' as nesting, so a key holding one of them would arrive as a
        different key, or as part of the value: it throws instead.
    .PARAMETER Arguments
        The list the pairs are added to.
    .PARAMETER Flag
        '--field' or '--raw-field', repeated before every pair.
    .PARAMETER Parent
        The enclosing field's full name, brackets included; empty for a
        top-level field.
    .PARAMETER Key
        The field's own key.
    .PARAMETER Value
        The field's value.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[string]]$Arguments,

        [Parameter(Mandatory)]
        [string]$Flag,

        [string]$Parent,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Key,

        [AllowNull()]
        [object]$Value
    )

    if ($Key.IndexOfAny([char[]]'=[]') -ge 0) {
        $shownKey = Hide-UrlCredential -Text $Key
        throw "Field key '$shownKey' holds '=', '[' or ']', which gh reads as part of its key[name]=value syntax" +
        " - send it with -Body."
    }

    $name = if ($Parent) { "$Parent[$Key]" } else { $Key }
    if ($Value -is [IDictionary]) {
        if ($Value.PSBase.Count -eq 0) {
            $shown = Hide-UrlCredential -Text $name
            throw "Field '$shown' is an empty hashtable, which gh's fields cannot express - send it with -Body."
        }

        $keys = $Value.PSBase.Keys | Sort-Object
        foreach ($inner in $keys) {
            Add-GitHubFieldArgument -Arguments $Arguments -Flag $Flag -Parent $name -Key $inner -Value $Value[$inner]
        }

        return
    }

    if ($Value -isnot [IList]) {
        $Arguments.Add($Flag)
        $Arguments.Add("$name=$(Format-GitHubFieldValue -Name $name -Value $Value)")
        return
    }

    if ($Value.Count -eq 0) {
        $Arguments.Add($Flag)
        $Arguments.Add("$name[]")
    }

    foreach ($item in $Value) {
        if ($item -is [IDictionary] -or $item -is [IList]) {
            $shown = Hide-UrlCredential -Text $name
            throw "Field '$shown' holds a list of objects or lists, which gh's fields cannot express" +
            " - send it with -Body."
        }

        $Arguments.Add($Flag)
        $Arguments.Add("$name[]=$(Format-GitHubFieldValue -Name $name -Value $item)")
    }
}
