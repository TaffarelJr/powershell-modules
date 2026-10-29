function Write-Warn {
    <#
    .SYNOPSIS
        Reports something worth attention that does not stop the run.
    .DESCRIPTION
        Named Warn, not Warning,
        so it never shadows the built-in Write-Warning cmdlet
        and its warning-stream semantics
        ($WarningPreference, -WarningAction, -WarningVariable).
    .PARAMETER Text
        The line to print.
    .PARAMETER Indent
        Overrides the ambient indent (see Push-Indent) for this line only.
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
        [string]$Text,

        [ValidateRange('NonNegative')]
        [int]$Indent = -1
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            Write-MarkerLine -Text $Text -Marker '⚠️  ' -Color Yellow -Indent $Indent
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
