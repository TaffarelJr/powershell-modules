function Write-Warn {
    <#
    .SYNOPSIS
        Reports something worth attention that does not stop the run.
    .DESCRIPTION
        Writes the text in yellow, behind a warning sign. A line left open by
        Write-Doing is ended first.

        Named Warn, not Warning,
        so it never shadows the built-in Write-Warning cmdlet
        and its warning-stream semantics
        ($WarningPreference, -WarningAction, -WarningVariable).
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Write-Warn 'The cache is stale'

        Prints a yellow line starting with a warning sign.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            Write-MarkerLine -Text $Text -Outcome Warn
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
