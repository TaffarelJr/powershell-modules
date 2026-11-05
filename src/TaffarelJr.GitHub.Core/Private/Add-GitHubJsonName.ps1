function Add-GitHubJsonName {
    <#
    .SYNOPSIS
        Works out the property name a JSON key becomes, remembers it, and
        returns it.
    .DESCRIPTION
        Not exported. Called once per distinct key in a conversion; every
        later object looks the name up in the context's cache instead.

        Each underscore-separated segment is capitalized on its own and the
        segments are joined, so camelCase (headRefName) and snake_case
        (head_ref_name) both become PascalCase (HeadRefName). A key that
        re-cases to nothing - one made only of underscores - keeps its own
        name. The key is also marked as a date's when it ends in At, _at,
        or Date, with that case.
    .PARAMETER Context
        The conversion's context, from New-GitHubJsonContext.
    .PARAMETER Name
        The key as the JSON has it.
    .OUTPUTS
        The property name.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    $target = $Name
    if (-not $Context.KeepFieldNames) {
        $builder = [System.Text.StringBuilder]::new($Name.Length)
        foreach ($segment in $Name.Split('_')) {
            if ($segment.Length -gt 0) {
                $builder.Append([char]::ToUpperInvariant($segment[0])) | Out-Null
                $builder.Append($segment, 1, $segment.Length - 1) | Out-Null
            }
        }

        if ($builder.Length -gt 0) {
            $target = $builder.ToString()
        }
    }

    $Context.Names[$Name] = $target
    $Context.DateKeys[$Name] = $Name -cmatch '(?:At|_at|Date)$'
    return $target
}
