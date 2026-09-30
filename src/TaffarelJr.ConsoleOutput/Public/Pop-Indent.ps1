function Pop-Indent {
    <#
    .SYNOPSIS
        Ends the most recently started indented region.
    .DESCRIPTION
        Warns rather than throwing when there is nothing to pop -
        a caller bug, but not one that should crash a run
        over a cosmetic mismatch.
    #>
    [CmdletBinding()]
    param()

    if ($script:IndentStack.Count -eq 0) {
        Write-Warning 'Pop-Indent called with no matching Push-Indent.'
        return
    }

    [void]$script:IndentStack.Pop()
}
