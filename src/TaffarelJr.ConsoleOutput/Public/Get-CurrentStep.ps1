function Get-CurrentStep {
    <#
    .SYNOPSIS
        Returns the current step's label ("Step 2: Build"),
        or an empty string when no step is active.
    .DESCRIPTION
        This module renders no failure banner of its own -
        lets a caller's own failure reporting reference which step was running,
        without this module needing to know anything about ErrorRecords.
    #>
    [CmdletBinding()]
    param()

    return $script:CurrentStepLabel
}
