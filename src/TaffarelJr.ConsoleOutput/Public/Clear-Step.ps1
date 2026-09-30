function Clear-Step {
    <#
    .SYNOPSIS
        Forgets the current step and resets the step counter.
    .DESCRIPTION
        Call once, after the last step - not after each one;
        there is no per-step teardown.
        Without it, a later failure in the same session
        reports a step number that continues from the last run
        instead of starting over, and blames a step that had already succeeded.
    #>
    [CmdletBinding()]
    param()

    $script:StepNumber = 0
    $script:CurrentStepLabel = ''
}
