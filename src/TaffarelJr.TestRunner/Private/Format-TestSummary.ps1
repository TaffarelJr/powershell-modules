function Format-TestSummary {
    <#
    .SYNOPSIS
        Renders the closing line:
        files, cases passed and failed, crashes, and the wall time.
    .DESCRIPTION
        Clears Tally first: this module's own tallies
        are module-scoped state, not a fresh local variable,
        so a second call in the same process
        (as a test of this very function makes)
        would otherwise accumulate on top of the first instead of starting over.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results,

        [Parameter(Mandatory)]
        [TimeSpan]$Elapsed
    )

    Clear-Tally
    foreach ($result in $Results) {
        Add-Tally -Name 'passed' -Amount $result.Passed
        Add-Tally -Name 'failed' -Amount $result.Failed
        if ($result.Crashed) {
            Add-Tally -Name 'crashed'
        }
    }

    $tally = Format-Tally -Name 'passed', 'failed', 'crashed'
    return '{0} file(s) - {1} - {2:m\:ss}' -f $Results.Count, $tally, $Elapsed
}
