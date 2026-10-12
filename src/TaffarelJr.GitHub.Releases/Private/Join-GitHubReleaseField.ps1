using namespace System.Collections.Generic

function Join-GitHubReleaseField {
    <#
    .SYNOPSIS
        Returns the --json field list for a release read, with the fields a
        release needs to be piped on always included.
    .DESCRIPTION
        The fields are read as ConvertTo-GitHubJsonFieldList reads them;
        each required field missing from them is added at the end, so a
        release read with chosen fields still carries its tag, and its Url
        where gh offers one.
    .PARAMETER Property
        The fields the caller chose, or nothing for the default set.
    .PARAMETER Default
        The comma-separated default field list.
    .PARAMETER Required
        The fields always sent, as gh spells them.
    .OUTPUTS
        The comma-separated field list for gh's --json.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [string[]]$Property,

        [Parameter(Mandatory)]
        [string]$Default,

        [Parameter(Mandatory)]
        [string[]]$Required
    )

    $list = ConvertTo-GitHubJsonFieldList -Property $Property -Default $Default
    $fields = [List[string]]::new([string[]]$list.Split(','))
    foreach ($field in $Required) {
        if (-not $fields.Contains($field)) {
            $fields.Add($field)
        }
    }

    return $fields -join ','
}
