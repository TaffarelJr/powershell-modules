using namespace System.Diagnostics.CodeAnalysis

function Set-StepState {
    <#
    .SYNOPSIS
        Records the current step's number and label.
    .DESCRIPTION
        Not exported. The one place the step state is written: Write-Step
        records a step that has started, Clear-Step forgets it (number 0, no
        label).
    .PARAMETER Number
        The step's number; 0 when no step is active.
    .PARAMETER Label
        The step's label, as Get-CurrentStep returns it; empty when no step is
        active.
    #>
    [CmdletBinding()]
    [SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Changes the step state this module keeps in memory; nothing outside the process changes.')]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Label
    )

    $script:StepNumber = $Number
    $script:CurrentStepLabel = $Label
}
