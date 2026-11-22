function Get-CurrentStep {
    <#
    .SYNOPSIS
        Returns the current step's label, such as "Step 2: Build", or an empty
        string when no step is active.
    .DESCRIPTION
        This module prints no failure message of its own. This lets a
        caller's own error handling name the step that was running, without
        keeping a counter itself.
    .INPUTS
        None.
    .OUTPUTS
        System.String. The label of the current step, or an empty string.
    .EXAMPLE
        Show-Step 'Build'
        Get-CurrentStep

        Returns "Step 1: Build", the step Show-Step started.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Clear-Step
    .LINK
        Show-Step
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $script:CurrentStepLabel
}
