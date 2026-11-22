New-Variable -Name SuccessMarker -Value "`u{2705} " -Option Constant -Scope Script

function Show-Success {
    <#
    .SYNOPSIS
        Reports that something was done.
    .DESCRIPTION
        Writes the text in green, behind a check mark, at the current indent.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Show-Success 'Build complete'

        Prints a green line starting with a check mark.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Show-Failure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        Write-Host "$(Get-Indent)$script:SuccessMarker$Text" -ForegroundColor Green
    }
}
