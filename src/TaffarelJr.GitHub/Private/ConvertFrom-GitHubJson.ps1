function ConvertFrom-GitHubJson {
    <#
    .SYNOPSIS
        Parses gh's JSON output lines into objects with PascalCase
        property names.
    .DESCRIPTION
        Not exported. The lines are parsed as one document, so a JSON
        array stays one array - never unrolled to a scalar, never $null
        for an empty one - and the result is re-cased by
        ConvertTo-PascalCaseObject unless -KeepFieldNames says otherwise.
    .PARAMETER Lines
        gh's output lines, as Invoke-GitHubCommand returns them.
    .PARAMETER KeepFieldNames
        Leaves property names exactly as the JSON had them. For a raw API
        response, whose snake_case names are GitHub's documented contract.
    .OUTPUTS
        A PSCustomObject for a JSON object; an array (always, even empty
        or one-element) for a JSON array; $null when there was no output
        at all. A caller passing an array result on must keep the leading
        comma on its own return.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [switch]$KeepFieldNames
    )

    $text = ($Lines -join "`n").Trim()
    if (-not $text) {
        return $null
    }

    $result = ConvertFrom-Json -InputObject $text -NoEnumerate
    if (-not $KeepFieldNames) {
        $result = ConvertTo-PascalCaseObject -InputObject $result
    }

    if ($result -is [array]) {
        return , $result
    }

    return $result
}
