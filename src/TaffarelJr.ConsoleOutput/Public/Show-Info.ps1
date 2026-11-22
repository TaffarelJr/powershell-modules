New-Variable -Name InfoMarker -Value "`u{2139}`u{FE0F}  " -Option Constant -Scope Script

function Show-Info {
    <#
    .SYNOPSIS
        Reports a neutral note, neither an outcome nor a problem.
    .DESCRIPTION
        Writes the text in gray, behind an information marker, at the current
        indent.
        If a line was left open, it is ended first.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Show-Info 'Restoring packages'

        Prints a gray line starting with an information marker.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Show-Detail
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        Show-LineBreak
        Write-Host "$(Get-Indent)$script:InfoMarker$Text" -ForegroundColor Gray
    }
}
