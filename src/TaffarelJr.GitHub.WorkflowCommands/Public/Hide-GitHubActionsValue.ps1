function Hide-GitHubActionsValue {
    <#
    .SYNOPSIS
        Masks a value out of the run's log, replacing it with '***'
        everywhere it appears from this point on.
    .DESCRIPTION
        Masking applies to this job's log only, and only to output
        written after this call - earlier lines, and any other job, are
        unaffected.
    .PARAMETER Value
        The secret to mask. The runner ignores a value a few characters
        or shorter, since matching it would also blot out unrelated
        text.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Value
    )

    process {
        Write-GitHubActionsCommand -Command 'add-mask' -Data $Value
    }
}
