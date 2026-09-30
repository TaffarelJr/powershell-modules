function Invoke-Indented {
    <#
    .SYNOPSIS
        Runs a script block with an indented region active,
        putting the indent back where it started even if the block throws.
    .DESCRIPTION
        The block runs in the caller's own scope, as ForEach-Object's does,
        so a variable it assigns is the caller's variable.
        A block that leaves Push-Indent levels of its own behind,
        or pops more than it pushed, gets a warning,
        and the caller's indent is put back all the same.

        An error the block throws is raised by this command, as a terminating
        error that carries the block's own exception, once the indent is back.
    .PARAMETER ScriptBlock
        The code to run with the indent active.
    .PARAMETER Width
        Spaces added for the duration of the script block. See Push-Indent.
    .INPUTS
        None.
    .OUTPUTS
        System.Object. Whatever the script block writes, one item at a time.
    .EXAMPLE
        Invoke-Indented { Write-Info 'nested line' }

        Prints the line two spaces further in than the lines around it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Push-Indent
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1)]
        [ValidateRange('NonNegative')]
        [int]$Width = $script:IndentWidth
    )

    try {
        $ErrorActionPreference = 'Stop'

        $before = $script:IndentStack.ToArray()
        Push-Indent -Width $Width
        try {
            # Dot-sourced: a call with & gets a scope of its own, and the block's
            # assignments would be lost when it ends.
            . $ScriptBlock
        }
        finally {
            $extra = $script:IndentStack.Count - $before.Count - 1
            if ($extra -ne 0) {
                $imbalance = if ($extra -gt 0) {
                    "pushed $extra indent level(s) more than it popped"
                }
                else {
                    "popped $(-$extra) indent level(s) more than it pushed"
                }
                Write-Warning (
                    "Invoke-Indented: the script block $imbalance; " +
                    'the indent is put back to where the block started.'
                )
            }

            $script:IndentStack.Clear()
            for ($i = $before.Count - 1; $i -ge 0; $i--) {
                $script:IndentStack.Push($before[$i])
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
