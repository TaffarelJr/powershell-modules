function Complete-TestRun {
    <#
    .SYNOPSIS
        Prints the pass/fail tally and returns the failure count,
        so a runner can use it as the file's exit code.
    #>
    $color = if ($script:FailCount -gt 0) { 'Red' } else { 'Green' }
    Write-Host ''
    Write-Host "$script:PassCount passed, $script:FailCount failed" -ForegroundColor $color
    return $script:FailCount
}
