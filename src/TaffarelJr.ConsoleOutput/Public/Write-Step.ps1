function Write-Step {
    <#
    .SYNOPSIS
        Starts a numbered step, recording it so a later failure can name it.
    .DESCRIPTION
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

            $script:StepNumber++
            $script:CurrentStepLabel = "Step ${script:StepNumber}: $(Format-MessageText $Text)"
            Write-Header -Text $script:CurrentStepLabel
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
