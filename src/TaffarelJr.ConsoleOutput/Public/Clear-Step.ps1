function Clear-Step {
    <#
    .SYNOPSIS
        Forgets the current step, resets the step counter,
        and ends a line Write-Doing left open.
    .DESCRIPTION
        Call once, after the last step - not after each one;
        there is no per-step teardown.
        Without it, a later failure in the same session
        reports a step number that continues from the last run
        instead of starting over, and blames a step that had already succeeded.
        A Write-Doing line is left open when the work it announced throws
        before Write-Done runs; ending it here keeps the next run's first
        line, and its Write-Done, off the end of it.
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
        Write-Step
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Resets the in-memory step state; nothing outside the process changes.')]
    param()

    try {
        $ErrorActionPreference = 'Stop'

        Close-OpenLine
        $script:StepNumber = 0
        $script:CurrentStepLabel = ''
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
