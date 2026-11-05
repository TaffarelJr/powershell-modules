function Complete-TestRun {
    <#
    .SYNOPSIS
        Prints the pass/fail tally and returns the exit code for the file.
    .DESCRIPTION
        The exit code is the failure count, capped at 255 because a
        POSIX exit status keeps only its low eight bits - 256 failures
        would otherwise exit as success.

        A file that made no assertions at all fails, since that is
        indistinguishable from a bug that skipped them all. A check of any
        shape still counts if it ends in Assert-That -Condition. A file
        skipped on purpose says so with Skip-TestRun; one that genuinely
        checks by other means - throwing on a bad result, say - says so
        with -AllowEmpty.

        The tally is emptied as it is read, so the next file run in the
        same session - from a prompt, say - counts only its own cases.
    .PARAMETER AllowEmpty
        Accepts a file that made no assertions, instead of failing it. The
        file is then responsible for failing itself, by throwing. An empty
        file accepted this way prints "allowed empty - checks run by other
        means" just before its tally line, so a runner can tell it from a
        file that crashed before asserting anything.
    .INPUTS
        None.
    .OUTPUTS
        System.Int32. The exit code for the file: the number of failed cases,
        at most 255, or 1 for a file that asserted nothing without
        -AllowEmpty.
    .EXAMPLE
        exit (Complete-TestRun)

        The last line of every test file: the exit code is how its
        failures reach the run.
    .EXAMPLE
        exit (Complete-TestRun -AllowEmpty)

        Ends a file whose checks throw instead of going through the kit.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Skip-TestRun
    #>
    [CmdletBinding()]
    [OutputType([int])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Reports a test result to the person at the console; it is not data.')]
    param(
        [switch]$AllowEmpty
    )

    try {
        $ErrorActionPreference = 'Stop'

        $counts = Reset-TestTally
        $empty = $counts.Passed + $counts.Failed -eq 0
        $color = if ($counts.Failed -gt 0) { 'Red' } else { 'Green' }
        Write-Host ''
        if ($empty -and $AllowEmpty) {
            Write-Host 'allowed empty - checks run by other means'
        }

        Write-Host "$($counts.Passed) passed, $($counts.Failed) failed" -ForegroundColor $color
        if ($empty -and -not $AllowEmpty) {
            $guidance = 'No assertions ran. Skip-TestRun marks a file skipped on purpose; ' +
                '-AllowEmpty marks one whose checks do not go through the kit.'
            Write-Host $guidance -ForegroundColor Red
            return 1
        }

        return [Math]::Min($counts.Failed, 255)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
