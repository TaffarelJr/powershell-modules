function ConvertTo-JsonLiteral {
    <#
    .SYNOPSIS
        Renders one value as a single-line JSON literal.
    .DESCRIPTION
        Not exported. The workspace file is assembled as text so it can
        carry comments, which leaves every key and value to be escaped by
        hand - this is the one place that happens.
    .PARAMETER Value
        The string, number, boolean, array, or dictionary to render.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    return ConvertTo-Json -InputObject $Value -Compress -Depth 10
}
