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
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Text
    )

    process {
        $script:StepNumber++
        $script:CurrentStepLabel = "Step ${script:StepNumber}: $Text"
        Write-Header -Text $script:CurrentStepLabel
    }
}
