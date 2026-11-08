function Pop-Indent {
    <#
    .SYNOPSIS
        Ends the most recently started indented region.
    .DESCRIPTION
        Warns rather than throwing when there is nothing to pop -
        a caller bug, but not one that should crash a run
        over a cosmetic mismatch. The warning follows the caller's
        $WarningPreference and -WarningAction: SilentlyContinue hides it, and
        Stop makes it an error. A line left open by Write-Doing is ended
        before a warning that is shown, so it does not run on to the end of
        it; a hidden warning leaves the line alone.
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

        if (-not $PSBoundParameters.ContainsKey('WarningAction')) {
            $WarningPreference = $PSCmdlet.GetVariableValue('WarningPreference')
        }

        if (-not (Remove-IndentLevel)) {
            Write-WarningLine -Message 'Pop-Indent called with no matching Push-Indent.'
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
