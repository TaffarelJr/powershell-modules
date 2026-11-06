function Write-Info {
    <#
    .SYNOPSIS
        Reports a neutral note, neither an outcome nor a problem.
    .DESCRIPTION
        Writes the text in gray, behind an information marker. A line left
        open by Write-Doing is ended first.
    .PARAMETER Text
        The line to print.
    .PARAMETER Indent
        Overrides the ambient indent (see Push-Indent) for this line only.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Write-Info 'Restoring packages'

        Prints a gray line starting with an information marker.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Detail
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

            Write-MarkerLine -Text $Text -Marker 'ℹ️  ' -Color Gray -Indent $Indent
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
