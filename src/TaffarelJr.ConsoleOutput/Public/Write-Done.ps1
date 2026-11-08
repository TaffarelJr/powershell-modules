function Write-Done {
    <#
    .SYNOPSIS
        Closes the line opened by Write-Doing, with its outcome.
    .DESCRIPTION
        Writes the outcome at the end of the open line: green by default,
        dark gray with -Skip, and yellow with -Warn. A later line of a
        multi-line outcome is indented under the Write-Doing text.

        With no Write-Doing line open, the outcome is printed on a line of its
        own instead, as Write-Success, Write-Skip or Write-Warn prints it, so a
        caller does not have to track whether one is open. One Write-Doing has
        one outcome: of several piped values, only the first closes the open
        line, and each later one prints on a line of its own.
    .PARAMETER Text
        Overrides the default outcome wording ("done", "already done" with
        -Skip, or "warning" with -Warn).
        A blank or $null value keeps the default wording.
    .PARAMETER Skip
        Marks the outcome as unchanged rather than done,
        the same distinction Write-Skip makes on its own line.
        Cannot be combined with -Warn.
    .PARAMETER Warn
        Marks the outcome as neither a success nor a failure, such as
        "skipped" or "would create", the same distinction Write-Warn makes
        on its own line. Cannot be combined with -Skip.
    .INPUTS
        System.String. The outcome's wording; each one is printed in turn.
    .OUTPUTS
        None. The outcome is written to the host.
    .EXAMPLE
        Write-Doing 'Installing'
        Write-Done 'installed 3 packages'

        Ends the open line with its own outcome instead of "done".
    .EXAMPLE
        Write-Doing 'Creating the folder'
        Write-Done -Warn 'would create'

        Ends the open line in yellow, for an outcome that is neither done
        nor already done.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Doing
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
        try {
            $ErrorActionPreference = 'Stop'

            $outcome = if ($Skip) {
                'Skip'
            }
            elseif ($Warn) {
                'Warn'
            }
            else {
                'Success'
            }

            Complete-OpenLine -Outcome $outcome -Text $Text
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
