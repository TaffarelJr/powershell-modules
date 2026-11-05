function Skip-TestRun {
    <#
    .SYNOPSIS
        Prints why a test file is not running here and returns the exit
        code for it; end the file with exit (Skip-TestRun -Reason ...).
    .DESCRIPTION
        For a file whose subject is unavailable on this machine - no
        authenticated gh, a Windows-only behavior - so it reports why and
        exits cleanly instead of failing. It only returns the code: called
        without exit, the file goes on to run its cases.

        Throws if assertions have already run: a file is either skipped or
        run. Either way the tally is emptied, so the next file run in the
        same session starts from nothing.
    .PARAMETER Reason
        Why the file is not running, printed after "skipped - ".
    .INPUTS
        None.
    .OUTPUTS
        System.Int32. The exit code for the skipped file, always 0.
    .EXAMPLE
        if (-not (Get-Command -Name gh -ErrorAction SilentlyContinue)) {
            exit (Skip-TestRun -Reason 'gh is not installed here')
        }

        Skips the file before its first case when its subject is missing.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Complete-TestRun
    #>
    [CmdletBinding()]
    [OutputType([int])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Reports a test result to the person at the console; it is not data.')]
    param(
        [Parameter(Mandatory)]
        [string]$Reason
    )

    try {
        $ErrorActionPreference = 'Stop'

        $counts = Reset-TestTally
        if ($counts.Passed + $counts.Failed -gt 0) {
            throw 'Skip-TestRun was called after assertions ran; a file is either skipped or run, ' +
                'so call it before the first assertion.'
        }

        Write-Host "skipped - $Reason"
        Write-Host ''
        Write-Host '0 passed, 0 failed'
        return 0
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
