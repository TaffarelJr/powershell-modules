New-Variable -Name DetailMarker -Value '   ' -Option Constant -Scope Script

function Show-Detail {
    <#
    .SYNOPSIS
        Adds a continuation line, indented under the message above it.
    .DESCRIPTION
        Writes the text in dark gray, with no marker of its own, three spaces
        in from the current indent. Meant to sit under the text of a
        Show-Failure or Show-Success line.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Show-Failure 'Build failed'
        Show-Detail 'See build.log for the compiler output.'

        Adds a line under the failure.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Show-Info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        Write-Host "$(Get-Indent)$script:DetailMarker$Text" -ForegroundColor DarkGray
    }
}
