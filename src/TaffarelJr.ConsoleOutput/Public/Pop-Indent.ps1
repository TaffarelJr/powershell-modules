function Pop-Indent {
    <#
    .SYNOPSIS
        Ends the most recently started indented region.
    .DESCRIPTION
        Warns rather than throwing when there is nothing to pop -
        a caller bug, but not one that should crash a run
        over a cosmetic mismatch.
    .INPUTS
        None.
    .OUTPUTS
        None. The indent shrinks; nothing is returned.
    .EXAMPLE
        Push-Indent
        Write-Info 'nested line'
        Pop-Indent

        Prints the line one level in, then puts the indent back.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Push-Indent
    #>
    [CmdletBinding()]
    param()

    try {
        $ErrorActionPreference = 'Stop'

        if ($script:IndentStack.Count -eq 0) {
            Write-Warning 'Pop-Indent called with no matching Push-Indent.'
            return
        }

        [void]$script:IndentStack.Pop()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
