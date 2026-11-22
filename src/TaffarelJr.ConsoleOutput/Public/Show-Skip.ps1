New-Variable -Name SkipMarker -Value "`u{23ED}`u{FE0F}  " -Option Constant -Scope Script

function Show-Skip {
    <#
    .SYNOPSIS
        Reports that something was already done, so nothing changed.
    .DESCRIPTION
        Writes the text in dark gray, behind a skip marker, at the current
        indent.
        If a line was left open, it is ended first.
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
        Show-LineBreak
        Write-Host "$(Get-Indent)$script:SkipMarker$Text" -ForegroundColor DarkGray
    }
}
