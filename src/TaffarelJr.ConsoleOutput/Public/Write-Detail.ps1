function Write-Detail {
    <#
    .SYNOPSIS
        Adds a continuation line, indented under the message above it.
    .DESCRIPTION
        Writes the text in dark gray, with no marker of its own, three columns
        in from the indent: under the text of a Write-Success or Write-Failure
        line. Under the other writers it can be a column off, and it does not
        follow Write-Field's value column. A line left open by Write-Doing is
        ended first.
    .PARAMETER Text
        The line to print.
    .PARAMETER Indent
        Overrides the ambient indent (see Push-Indent) for this line only.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Write-Failure 'Build failed'
        Write-Detail 'See build.log for the compiler output.'

        Adds a line under the failure, lined up with its text.
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

            # Three spaces land a Detail line under the marker text above it.
            Write-MarkerLine -Text $Text -Marker '   ' -Color DarkGray -Indent $Indent
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
