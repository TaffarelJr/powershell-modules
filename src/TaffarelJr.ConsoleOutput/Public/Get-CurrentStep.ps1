function Get-CurrentStep {
    <#
    .SYNOPSIS
        Returns the current step's label ("Step 2: Build"),
        or an empty string when no step is active.
    .DESCRIPTION
        This module renders no failure banner of its own; this lets a
        caller's own failure reporting name the step that was running,
        without this module needing to know anything about ErrorRecords.
    .INPUTS
        None.
    .OUTPUTS
        System.String. The label of the current step, or an empty string.
    .EXAMPLE
        Write-Step 'Build'
        Get-CurrentStep

        Returns "Step 1: Build" once Write-Step has started that step.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Step
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $ErrorActionPreference = 'Stop'

        return $script:CurrentStepLabel
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
