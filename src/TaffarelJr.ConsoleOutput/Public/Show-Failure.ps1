New-Variable -Name FailureMarker -Value "`u{274C} " -Option Constant -Scope Script

function Show-Failure {
    <#
    .SYNOPSIS
        Reports that something did not succeed.
    .DESCRIPTION
        Writes the text in red, behind a cross, at the current indent.

        Prints a single formatted message; it does not render an ErrorRecord.
        A terminating error is better served by a plain throw and
        PowerShell's own error display. This is for a "this one thing failed"
        line alongside Show-Skip and Show-Success.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Show-Failure 'Build failed'

        Prints a red line starting with a cross.
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
        Write-Host "$(Get-Indent)$script:FailureMarker$Text" -ForegroundColor Red
    }
}
