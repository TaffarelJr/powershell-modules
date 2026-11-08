function Write-Step {
    <#
    .SYNOPSIS
        Starts a numbered step, recording it so a later failure can name it.
    .DESCRIPTION
        Prints a header, drawn as Write-Header draws one, reading
        "Step N: title".
        The step number auto-increments -
        there is nothing for the caller to track.
        Steps do not nest: a second call replaces the first.
    .PARAMETER Text
        The step's title.
    .INPUTS
        System.String. The step's title; each one starts a step in turn.
    .OUTPUTS
        None. The step's header is written to the host.
    .EXAMPLE
        Write-Step 'Build'

        Prints a header reading "Step 1: Build", and remembers it for
        Get-CurrentStep.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-CurrentStep
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            $number = (Get-StepState).Number + 1
            $label = "Step ${number}: $(Format-MessageText $Text)"
            Write-Box -Text $label

            # Recorded only once the header is drawn: a step that failed to
            # start must not use up a number or become the current step.
            Set-StepState -Number $number -Label $label
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
