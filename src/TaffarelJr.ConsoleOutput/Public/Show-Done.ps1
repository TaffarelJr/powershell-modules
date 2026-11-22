function Show-Done {
    <#
    .SYNOPSIS
        Ends the line Show-Doing left open, with how it went.
    .DESCRIPTION
        Writes the outcome at the end of the open line: green by default, dark
        gray with -Skip, and yellow with -Warn.

        With no line open, the outcome is written on a line of its own
        instead, as Show-Success, Show-Skip or Show-Warning writes it, so a
        caller does not have to track whether one is open. One Show-Doing has
        one outcome: of several piped values, only the first ends the open
        line, and each later one is written on a line of its own.
    .PARAMETER Text
        The outcome's wording, in place of the default: "done", "already
        done" with -Skip, or "warning" with -Warn. Blank or missing keeps the
        default.
    .PARAMETER Skip
        Marks the outcome as unchanged rather than done, the distinction
        Show-Skip makes on its own line. Cannot be combined with -Warn.
    .PARAMETER Warn
        Marks the outcome as neither a success nor a failure, such as "would
        create", the distinction Show-Warning makes on its own line. Cannot be
        combined with -Skip.
    .INPUTS
        System.String. The outcome's wording; each one is written in turn.
    .OUTPUTS
        None. The outcome is written to the host.
    .EXAMPLE
        Show-Doing 'Installing'
        Show-Done 'installed 3 packages'

        Ends the open line with its own outcome instead of "done".
    .EXAMPLE
        Show-Doing 'Creating the folder'
        Show-Done -Warn 'would create'

        Ends the open line in yellow, for an outcome that is neither done nor
        already done.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Invoke-Doing
    .LINK
        Show-Doing
    #>
    [CmdletBinding(DefaultParameterSetName = 'Done')]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Text,

        [Parameter(ParameterSetName = 'Skip')]
        [switch]$Skip,

        [Parameter(ParameterSetName = 'Warn')]
        [switch]$Warn
    )

    process {
        $outcome = 'Success'
        if ($Skip) {
            $outcome = 'Skip'
        }
        elseif ($Warn) {
            $outcome = 'Warn'
        }

        Show-Outcome -Outcome $outcome -Text $Text
    }
}
