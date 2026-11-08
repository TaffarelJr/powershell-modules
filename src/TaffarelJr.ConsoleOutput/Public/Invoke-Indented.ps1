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
        The warning follows the caller's $WarningPreference and
        -WarningAction: SilentlyContinue hides it, and Stop makes it an error,
        raised once the indent is back.

        An error the block throws is raised by this command, as a terminating
        error that carries the block's own exception, once the indent is back.
        It stays the error raised even when the caller's -WarningAction Stop
        would turn the mismatch warning into one.
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

        if (-not $PSBoundParameters.ContainsKey('WarningAction')) {
            $WarningPreference = $PSCmdlet.GetVariableValue('WarningPreference')
        }

        $before = @(Get-IndentLevel)
        Add-IndentLevel -Width $Width
        $failed = $true
        try {
            # Dot-sourced: with & the block gets a scope of its own, and its
            # assignments would be lost when it ends.
            . $ScriptBlock
            $failed = $false
        }
        finally {
            $extra = @(Get-IndentLevel).Count - $before.Count - 1

            # Put the indent back before warning: a caller's -WarningAction Stop
            # turns the warning into an error that would skip the restore.
            Restore-IndentLevel -Level $before

            if ($extra -ne 0) {
                $imbalance = if ($extra -gt 0) {
                    "pushed $extra indent level(s) more than it popped"
                }
                else {
                    "popped $(-$extra) indent level(s) more than it pushed"
                }

                $message = "Invoke-Indented: the script block $imbalance; " +
                    'the indent is put back to where the block started.'
                Write-WarningLine -Message $message -AfterFailure:$failed
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
