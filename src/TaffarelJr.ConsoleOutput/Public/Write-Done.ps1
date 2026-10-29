function Write-Done {
    <#
    .SYNOPSIS
        Closes the line opened by Write-Doing, with its outcome.
    .DESCRIPTION
        Falls back to Write-Success/Write-Skip/Write-Warn -
        a fresh line, not a continuation -
        when no Write-Doing is open,
        so a caller does not have to track that itself.
        One Write-Doing has one outcome: of several piped values,
        only the first closes the open line,
        and each later one prints as its own
        Write-Success/Write-Skip/Write-Warn line.

        The outcome is green by default, dark gray with -Skip,
        and yellow with -Warn.
    .PARAMETER Text
        Overrides the default outcome wording ("done", "already done" with
        -Skip, or "warning" with -Warn).
        A blank or $null value keeps the default wording.
        A later line of a multi-line outcome is indented under
        the Write-Doing text.
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
        [Parameter(ParameterSetName = 'Done', Position = 0, ValueFromPipeline)]
        [Parameter(ParameterSetName = 'Skip', Position = 0, ValueFromPipeline)]
        [Parameter(ParameterSetName = 'Warn', Position = 0, ValueFromPipeline)]
        [string]$Text,

        [Parameter(ParameterSetName = 'Skip')]
        [switch]$Skip,

        [Parameter(ParameterSetName = 'Warn')]
        [switch]$Warn
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            $hasText = -not [string]::IsNullOrWhiteSpace($Text)
            $outcome = if ($hasText) {
                $Text
            }
            elseif ($Skip) {
                'already done'
            }
            elseif ($Warn) {
                'warning'
            }
            else {
                'done'
            }

            if (-not $script:LineOpen) {
                if ($Skip) {
                    Write-Skip -Text $outcome
                }
                elseif ($Warn) {
                    Write-Warn -Text $outcome
                }
                else {
                    Write-Success -Text $outcome
                }

                return
            }

            $script:LineOpen = $false
            $color = if ($Skip) {
                'DarkGray'
            }
            elseif ($Warn) {
                'Yellow'
            }
            else {
                'Green'
            }

            $message = Format-MessageText $outcome
            Write-MessageLine -Lead ' ' -Continuation $script:OpenLineContinuation -Text $message -Color $color
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
