function Read-TestTally {
    <#
    .SYNOPSIS
        Reads a file's "N passed, M failed" line out of its output,
        and decides whether it crashed:
        no tally at all, or a failing exit with nothing failed.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Output,
        [Parameter(Mandatory)][int]$ExitCode
    )

    $tallyLine = @($Output -match '^(\d+) passed, (\d+) failed$') | Select-Object -Last 1
    $tally = if ($tallyLine) { [regex]::Match($tallyLine, '^(\d+) passed, (\d+) failed$') }

    $passed = if ($tally) { [int]$tally.Groups[1].Value } else { 0 }
    $failed = if ($tally) { [int]$tally.Groups[2].Value } else { 0 }

    return [pscustomobject]@{
        Passed  = $passed
        Failed  = $failed
        Crashed = -not $tally -or ($ExitCode -ne 0 -and $failed -eq 0)
    }
}
