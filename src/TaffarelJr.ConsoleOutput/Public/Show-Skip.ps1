function Show-Skip {
    <#
    .SYNOPSIS
        Reports that something was already done, so nothing changed.
    .DESCRIPTION
        Writes the text in dark gray, behind a skip marker, at the current
        indent.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Show-Skip 'Packages are already restored'

        Prints a dark gray line starting with a skip marker.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Show-Success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        Write-Host "$(Get-Indent)`u{23ED}`u{FE0F}  $Text" -ForegroundColor DarkGray
    }
}
