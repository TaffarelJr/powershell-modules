using namespace System.Collections
using namespace System.Collections.Generic

function ConvertTo-GitHubFieldArgument {
    <#
    .SYNOPSIS
        Turns a hashtable of request parameters into gh api's repeated
        flag/value argument pairs.
    .DESCRIPTION
        Keys are emitted in sorted order so the argument
        vector is deterministic. An array value becomes one key[]=value
        pair per element (an empty array becomes a bare key[], gh's syntax
        for an empty list); a nested hashtable becomes key[name]=value
        pairs, one level of brackets per level of nesting. $null becomes
        null and a bool or switch becomes true or false in lower case,
        which gh's -F typing turns back into JSON null and booleans; a date
        is written in ISO 8601, not in the culture's own form. Any other
        value is written as its text: gh's -F types only an integer that
        fits a 64-bit number, so a fraction, a larger integer, an enum, a
        TimeSpan, or a char arrives as a JSON string. With --raw-field
        nothing is typed, so $null arrives as the text "null".

        A value gh's fields cannot express throws instead of being sent
        wrongly: a list of objects, an object that is not a hashtable, an
        empty nested hashtable (gh has no syntax for {}), or a key holding
        '=', '[' or ']', which gh would read as part of its own key syntax.
        Send those with Invoke-GitHubApi -Body.
    .PARAMETER Flag
        The gh flag repeated before every pair: '--field' or
        '--raw-field'.
    .PARAMETER Field
        The parameters, keyed by name. May be $null for none.
    .INPUTS
        None
    .OUTPUTS
        System.String
        Alternating flag and key=value strings, one at a time. Nothing
        when there are no fields, so wrap the call in @() to add it to an
        argument array.
    .EXAMPLE
        $set = @{ draft = $true; title = 'x' }
        $fields = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field $set)
        $arguments = @('api', 'repos/o/r/pulls', '--method', 'POST') + $fields

        Builds gh api ... --field draft=true --field title=x.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('--field', '--raw-field')]
        [string]$Flag,

        [Alias('Fields')]
        [IDictionary]$Field
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($null -eq $Field) {
            return
        }

        $arguments = [List[string]]::new()
        $keys = $Field.PSBase.Keys | Sort-Object
        foreach ($key in $keys) {
            Add-GitHubFieldArgument -Arguments $arguments -Flag $Flag -Key $key -Value $Field[$key]
        }

        return $arguments.ToArray()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
