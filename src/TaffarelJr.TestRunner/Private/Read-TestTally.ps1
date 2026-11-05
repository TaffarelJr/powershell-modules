function Read-TestTally {
    <#
    .SYNOPSIS
        Reads a file's pass/fail tally out of its output,
        and decides whether it crashed or was skipped.
    .DESCRIPTION
        A file crashed when it printed no tally at all, when it exited
        non-zero with nothing failed, or when its tally counts no case at all
        and it did not say why - a file whose assertions never ran is not a
        pass. A file is skipped when a "skipped - <reason>" line, the one
        Skip-TestRun prints, comes before a tally of no cases; it passes with
        no cases when the line "allowed empty - checks run by other means",
        the one Complete-TestRun -AllowEmpty prints, comes before it instead.

        Parsing goes through Tally's own Read-Tally rather than a regex
        hardcoded here, since TestKit's tally line already follows the same
        "<count> <name>" shape Read-Tally/Format-Tally use elsewhere -
        one tested parser instead of a second, parallel regex to maintain.
    .PARAMETER Output
        What the file printed, a line at a time. The last line holding both a
        passed and a failed count is the tally.
    .PARAMETER ExitCode
        The file's exit code.
    .OUTPUTS
        Passed, Failed, Crashed, Skipped, SkipReason (empty unless Skipped),
        and AllowedEmpty.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Output,

        [Parameter(Mandatory)]
        [int]$ExitCode
    )

    $tally = $null
    $tallyIndex = $Output.Count
    for ($i = $Output.Count - 1; $i -ge 0; $i--) {
        $counts = @{}
        foreach ($count in (Read-Tally -Text $Output[$i] -Separator ', ')) {
            $counts[$count.Name] = $count.Count
        }

        if ($counts.ContainsKey('passed') -and $counts.ContainsKey('failed')) {
            $tally = $counts
            $tallyIndex = $i
            break
        }
    }

    $passed = if ($tally) { $tally['passed'] } else { 0 }
    $failed = if ($tally) { $tally['failed'] } else { 0 }

    $skipReason = ''
    $skipped = $false
    $allowedEmpty = $false
    if ($tally -and $passed + $failed -eq 0) {
        for ($i = $tallyIndex - 1; $i -ge 0; $i--) {
            if ($Output[$i] -match '^skipped - (?<Reason>.*)$') {
                $skipReason = $Matches['Reason']
                $skipped = $true
                break
            }

            if ($Output[$i] -ceq 'allowed empty - checks run by other means') {
                $allowedEmpty = $true
                break
            }
        }
    }

    $noCases = $tally -and $passed + $failed -eq 0 -and -not $skipped -and -not $allowedEmpty
    $crashed = -not $tally -or $noCases -or ($ExitCode -ne 0 -and $failed -eq 0)
    if ($crashed) {
        $skipped = $false
        $skipReason = ''
        $allowedEmpty = $false
    }

    return [PSCustomObject]@{
        Passed       = $passed
        Failed       = $failed
        Crashed      = [bool]$crashed
        Skipped      = $skipped
        SkipReason   = $skipReason
        AllowedEmpty = $allowedEmpty
    }
}
