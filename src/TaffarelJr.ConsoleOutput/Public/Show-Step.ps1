function Show-Step {
    <#
    .SYNOPSIS
        Starts a numbered step: prints its header and remembers it as the
        current step.
    .DESCRIPTION
        Prints a header reading "Step N: title", drawn as Show-Header draws
        one: between two rules, in cyan, at the current indent. N is 1 for the
        first step and goes up by one with each call, so there is nothing for
        the caller to keep track of. Steps do not nest: a new step replaces
        the one before it. Get-CurrentStep returns the current step's label,
        and Clear-Step starts the numbering over.
    .PARAMETER Text
        The step's title. A line break starts a new line of the header.
    .INPUTS
        System.String. The step's title; each one starts a step in turn.
    .OUTPUTS
        None. The step's header is written to the host.
    .EXAMPLE
        Show-Step 'Build'

        Prints a header reading "Step 1: Build" between two rules, and
        remembers it for Get-CurrentStep.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Clear-Step
    .LINK
        Get-CurrentStep
    .LINK
        Show-Header
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        $number = $script:StepNumber + 1
        $label = "Step ${number}: $Text"

        Show-Box -Text $label

        $script:StepNumber = $number
        $script:CurrentStepLabel = $label
    }
}
