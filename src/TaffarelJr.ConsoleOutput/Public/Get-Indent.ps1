function Get-Indent {
    <#
    .SYNOPSIS
        Returns the current ambient indent, in spaces.
    .DESCRIPTION
        The sum of every width pushed by Push-Indent and not yet popped.
        Zero when nothing is pushed.
    .INPUTS
        None.
    .OUTPUTS
        System.Int32. The indent, in spaces.
    .EXAMPLE
        Push-Indent
        Get-Indent
        Pop-Indent

        Returns 2, the width Push-Indent adds when it is given none.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Push-Indent
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    try {
        $ErrorActionPreference = 'Stop'

        $total = 0
        foreach ($width in $script:IndentStack) {
            $total += $width
        }

        return $total
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
