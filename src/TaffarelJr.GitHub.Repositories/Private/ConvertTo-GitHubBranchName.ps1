using namespace System.Collections

function ConvertTo-GitHubBranchName {
    <#
    .SYNOPSIS
        Returns a branch's name from a name, a branch object, or a
        hashtable.
    .DESCRIPTION
        Not exported. An object - a listing's, or a hashtable - is read by
        its Name, so one whose Name is a number is named by that number and
        not by the object's text. A blank name, an object or hashtable
        without a Name, a list, and a bool throw, so none of them is looked
        up as the name of a branch that does not exist.

        A parameter that takes both a name and an object by pipeline must
        be an [object]: as a [string], PowerShell turns a piped object into
        its text ("@{Id=7}") when the property it binds by is not already
        text.
    .PARAMETER Branch
        A branch's name, or a branch object.
    .OUTPUTS
        The branch's name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [object]$Branch
    )

    if ($Branch -isnot [string] -and $Branch -isnot [IDictionary] -and $Branch -is [IEnumerable]) {
        throw "Give one branch at a time, not a list of $(@($Branch).Count); pipe them to name several."
    }

    if ($Branch -is [bool] -or $Branch -is [switch]) {
        throw "'$Branch' is not a branch name: give the branch's name, or a branch object."
    }

    $name = $Branch
    if ($Branch -isnot [string] -and $Branch -isnot [ValueType]) {
        $values = @{}
        if ($Branch -is [IDictionary]) {
            foreach ($key in $Branch.PSBase.Keys) {
                $values["$key"] = $Branch[$key]
            }
        }
        else {
            foreach ($property in $Branch.PSObject.Properties) {
                $values[$property.Name] = $property.Value
            }
        }

        if (-not $values.ContainsKey('Name')) {
            throw "A branch object needs a Name, and this one has none: $($Branch.GetType().Name)."
        }

        $name = $values['Name']
        if ($null -ne $name -and $name -isnot [string] -and $name -isnot [ValueType]) {
            throw "A branch object's Name must be text, and this one's is $($name.GetType().Name)."
        }
    }

    if ("$name" -notmatch '\S') {
        throw '-Branch is blank: give the branch''s name.'
    }

    return "$name"
}
