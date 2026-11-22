New-Variable -Name DoingMarker -Value "`u{25B6} " -Option Constant -Scope Script

function Show-Doing {
    <#
    .SYNOPSIS
        Announces what is about to be attempted, on a line left open for its
        outcome.
    .DESCRIPTION
        Writes the text in cyan, behind a play marker and followed by " ...",
        at the current indent, and leaves the line open. Pair it with
        Show-Done, which ends the line with how it went. If a line was left
        open, it is ended first.

        Any other command from this module that writes a line ends the open
        line first, so its text does not run on to the end of it. Output from
        anywhere else, such as the built-in Write-Warning, a native command or
        pipeline output reaching the host, does not: close the line with
        Show-Done before any of that.

        Under -InformationAction Ignore nothing is written, so no line is left
        open.
    .PARAMETER Text
        What is about to be attempted.
    .INPUTS
        System.String. What is about to be attempted; each one is announced in
        turn.
    .OUTPUTS
        None. The line is written to the host, left open.
    .EXAMPLE
        Show-Doing 'Compiling'
        Show-Done

        Announces the work, then ends its line with "done" once it is over.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Invoke-Doing
    .LINK
        Show-Done
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        Show-LineBreak

        if ($InformationPreference -ne 'Ignore') {
            $script:LineOpen = $true
        }

        Write-Host "$(Get-Indent)$script:DoingMarker$Text ..." -ForegroundColor Cyan -NoNewline
    }
}
