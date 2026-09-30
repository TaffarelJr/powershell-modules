function Expand-PathList {
    <#
    .SYNOPSIS
        Splits every comma-joined entry in a list apart, trims each
        result, and drops anything left empty - always as an array.
    .DESCRIPTION
        Not exported. A value arriving from an external invocation (pwsh
        -File, or a CI workflow's own shell step) can only ever bind one
        bare token per flag to an array parameter - 'Git,Tally' arrives as
        one element containing a comma, not two. This normalizes both
        forms the same way, so a caller already passing a real multi-
        element array sees no change at all.
    .PARAMETER Value
        The list to normalize.
    #>
    param(
        [string[]]$Value
    )

    return , @($Value | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
