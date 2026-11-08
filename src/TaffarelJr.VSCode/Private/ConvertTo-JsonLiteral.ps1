function ConvertTo-JsonLiteral {
    <#
    .SYNOPSIS
        Renders one value as a single-line JSON literal.
    .DESCRIPTION
        Not exported. The workspace file is assembled as text so it can
        carry comments, which leaves every key and value to be escaped by
        hand - this is the one place that happens. A setting's value is
        checked by Assert-JsonValue first, which also keeps it within the
        depth written here.
    .PARAMETER Value
        The string, number, boolean, array, or dictionary to render.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    return ConvertTo-Json -InputObject $Value -Compress -Depth 100
}
