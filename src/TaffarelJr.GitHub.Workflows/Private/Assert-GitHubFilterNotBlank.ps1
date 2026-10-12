using namespace System.Collections.Generic

function Assert-GitHubFilterNotBlank {
    <#
    .SYNOPSIS
        Throws when a filter parameter was given but is blank.
    .DESCRIPTION
        A blank filter would be dropped, widening the listing (or the
        deletion) to everything - as when the variable passed to it came
        back empty. Omitted is fine; given and blank is refused.
    .PARAMETER BoundParameters
        The caller's $PSBoundParameters.
    .PARAMETER Name
        The filter parameters to check, without their dash.
    .EXAMPLE
        Assert-GitHubFilterNotBlank -BoundParameters $PSBoundParameters `
            -Name 'Key', 'Ref'

        Throws for Get-GitHubCache -Key '', and passes when -Key is left
        out.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [IDictionary[string, object]]$BoundParameters,

        [Parameter(Mandatory)]
        [string[]]$Name
    )

    foreach ($parameter in $Name) {
        if ($BoundParameters.ContainsKey($parameter) -and "$($BoundParameters[$parameter])" -notmatch '\S') {
            throw "-$parameter was given but is blank, so it would filter nothing." +
            " Give a value, or leave -$parameter off."
        }
    }
}
