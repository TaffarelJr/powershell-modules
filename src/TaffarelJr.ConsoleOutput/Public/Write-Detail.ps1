function Write-Detail {
    <#
    .SYNOPSIS
        Adds a continuation line, indented under the message above it.
    .DESCRIPTION
        Writes the text in dark gray, lined up with the text of a line the
        module's other writers printed before it, and with no marker of its
        own. A line left open by Write-Doing is ended first.
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
