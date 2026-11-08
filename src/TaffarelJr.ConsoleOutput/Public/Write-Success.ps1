function Write-Success {
    <#
    .SYNOPSIS
        Reports that something was done.
    .DESCRIPTION
        Writes the text in green, behind a check mark. A line left open by
        Write-Doing is ended first.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Write-Success 'Build complete'

        Prints a green line starting with a check mark.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Failure
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

            Write-MarkerLine -Text $Text -Outcome Success
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
