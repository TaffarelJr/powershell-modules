function Get-StepState {
    <#
    .SYNOPSIS
        Returns the current step's number and label.
    .DESCRIPTION
        Not exported. The one place the step state is read; Set-StepState
        writes it.
    .OUTPUTS
        An object with Number (0 when no step is active) and Label (empty
        when no step is active).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        Number = $script:StepNumber
        Label  = $script:CurrentStepLabel
    }
}
