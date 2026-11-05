function ConvertTo-GitHubJsonFieldList {
    <#
    .SYNOPSIS
        Returns the comma-separated field list for gh's --json flag, from
        a caller's -Property values or a default.
    .DESCRIPTION
        Each value may be one field name or several separated by commas;
        each name is trimmed, an empty one is dropped, and its first letter
        is lower-cased, so the PascalCase name a result's property has
        (HeadRefName) asks for gh's own field (headRefName). Values that
        name no field at all - '', ' , ' - throw, rather than quietly
        meaning the default or reaching gh as an unknown field "".
    .PARAMETER Property
        The caller's field names. Leave it out, or pass $null or an empty
        array, for the default.
    .PARAMETER Default
        The field list to use when no -Property was given, as gh takes it.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The field list, as one string.
    .EXAMPLE
        $fields = ConvertTo-GitHubJsonFieldList `
            -Property 'Number, Title', 'url' -Default 'number,title,state,url'

        Gives 'number,title,url'.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Property,

        [Parameter(Mandatory)]
        [string]$Default
    )

    try {
        $ErrorActionPreference = 'Stop'

        if ($null -eq $Property -or $Property.Count -eq 0) {
            return $Default
        }

        $fields = foreach ($value in $Property) {
            foreach ($name in "$value".Split(',')) {
                $field = $name.Trim()
                if ($field) {
                    $field.Substring(0, 1).ToLowerInvariant() + $field.Substring(1)
                }
            }
        }

        $list = @($fields) -join ','
        if (-not $list) {
            $given = $Property -join "', '"
            throw "-Property names no field: '$given'. Give one or more field names, such as 'number,title'."
        }

        return $list
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
