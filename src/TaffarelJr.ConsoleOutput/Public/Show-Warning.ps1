function Show-Warning {
    <#
    .SYNOPSIS
        Reports something worth attention that does not stop the run.
    .DESCRIPTION
        Writes the text in yellow, behind a warning sign, at the current
        indent.

        This command writes to the host, not to the warning stream, so
        $WarningPreference, -WarningAction and -WarningVariable do not apply
        to it. Use the built-in Write-Warning for a warning that should.
    .PARAMETER Text
        The line to print.
    .INPUTS
        System.String. The line to print; each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Show-Warning 'The cache is stale'

        Prints a yellow line starting with a warning sign.
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
        Write-Host "$(Get-Indent)`u{26A0}`u{FE0F}  $Text" -ForegroundColor Yellow
    }
}
