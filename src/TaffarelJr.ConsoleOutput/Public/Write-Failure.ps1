function Write-Failure {
    <#
    .SYNOPSIS
        Reports that something did not succeed, on its own line.
    .DESCRIPTION
        Writes the text in red, behind a cross. A line left open by
        Write-Doing is ended first.

        Prints a single formatted message -
        it does not parse or render an ErrorRecord.
        A terminating error is better served by a plain throw
        and PowerShell's own error display;
        this is for a non-terminating "this one thing failed" line
        alongside Write-Success/Write-Skip.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Write-Failure 'Build failed'

        Prints a red line starting with a cross.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Success
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

            Write-MarkerLine -Text $Text -Outcome Failure
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
