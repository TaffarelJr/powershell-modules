function Read-TestTally {
    <#
    .SYNOPSIS
        Reads a file's pass/fail tally out of its output,
        and decides whether it crashed:
        no tally at all, or a failing exit with nothing failed.
    .DESCRIPTION
        Parsing goes through Tally's own Read-Tally rather than a regex
        hardcoded here, since TestKit's tally line already follows the same
        "<count> <name>" shape Read-Tally/Format-Tally use elsewhere -
        one tested parser instead of a second, parallel regex to maintain.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Output,
        [Parameter(Mandatory)][int]$ExitCode
    )

    $tally = $null
    for ($i = $Output.Count - 1; $i -ge 0; $i--) {
        $counts = @{}
        foreach ($count in (Read-Tally -Text $Output[$i] -Separator ', ')) {
            $counts[$count.Name] = $count.Count
        }

        if ($counts.ContainsKey('passed') -and $counts.ContainsKey('failed')) {
            $tally = $counts
            break
        }
    }

    $passed = if ($tally) { $tally['passed'] } else { 0 }
    $failed = if ($tally) { $tally['failed'] } else { 0 }

    return [PSCustomObject]@{
        Passed  = $passed
        Failed  = $failed
        Crashed = -not $tally -or ($ExitCode -ne 0 -and $failed -eq 0)
    }
}
