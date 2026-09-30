function Format-TestSummary {
    <#
    .SYNOPSIS
        Renders the closing line:
        files, cases passed and failed, files crashed and skipped,
        and the wall time.
    .DESCRIPTION
        Counts under a key of its own, forgotten afterward, so a second call
        starts from zero and nobody else's counters are touched.
    .PARAMETER Results
        Every file's result, from Invoke-TestFileProcess.
    .PARAMETER Elapsed
        How long the whole run took, shown as minutes:seconds.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results,

        [Parameter(Mandatory)]
        [TimeSpan]$Elapsed
    )

    $key = "TaffarelJr.TestRunner.Summary.$([Guid]::NewGuid())"
    try {
        foreach ($result in $Results) {
            Add-Tally -Name 'passed' -Amount $result.Passed -Key $key
            Add-Tally -Name 'failed' -Amount $result.Failed -Key $key
            if ($result.Crashed) {
                Add-Tally -Name 'crashed' -Key $key
            }

            if ($result.Skipped) {
                Add-Tally -Name 'skipped' -Key $key
            }
        }

        $tally = Format-Tally -Name 'passed', 'failed', 'crashed', 'skipped' -Key $key
    }
    finally {
        Clear-Tally -Key $key
    }

    $minutes = [int][Math]::Floor($Elapsed.TotalMinutes)
    return '{0} file(s) - {1} - {2}:{3:00}' -f $Results.Count, $tally, $minutes, $Elapsed.Seconds
}
