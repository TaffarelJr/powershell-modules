function Clear-Step {
    <#
    .SYNOPSIS
        Forgets the current step and starts the step numbering over.
    .DESCRIPTION
        Call it once, after the last step, not after each one: there is no
        per-step teardown. Without it, a later run in the same session
        carries on from the last step number instead of starting at Step 1,
        and Get-CurrentStep goes on naming a step that has already finished.
        Clearing when no step is active changes nothing.
    .INPUTS
        None.
    .OUTPUTS
        None. The step state is reset; nothing is returned.
    .EXAMPLE
        Clear-Step

        Resets the step count after the last step of a run, so the next run
        starts again at Step 1.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-CurrentStep
    .LINK
        Show-Step
    #>
    [CmdletBinding()]
    param()

    $script:StepNumber = 0
    $script:CurrentStepLabel = ''
}
