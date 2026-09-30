function Expand-PathList {
    <#
    .SYNOPSIS
        Splits every comma-joined entry in a list apart, trims each
        result, and drops anything left empty. An entry that is itself an
        existing path is kept whole, comma and all.
    .DESCRIPTION
        Not exported. A value arriving from an external invocation (pwsh
        -File, or a CI workflow's own shell step) can only ever bind one
        bare token per flag to an array parameter - 'Git,Tally' arrives as
        one element containing a comma, not two. This normalizes both
        forms the same way, so a caller already passing a real multi-
        element array sees no change at all - unless an entry names a folder
        whose own name has a comma in it, which stays one entry.
    .PARAMETER Value
        The list to normalize.
    .OUTPUTS
        The entries, one at a time.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Value
    )

    foreach ($entry in $Value) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }

        if (Test-Path -LiteralPath $entry) {
            $entry
            continue
        }

        foreach ($part in $entry -split ',') {
            $trimmed = $part.Trim()
            if ($trimmed) {
                $trimmed
            }
        }
    }
}
