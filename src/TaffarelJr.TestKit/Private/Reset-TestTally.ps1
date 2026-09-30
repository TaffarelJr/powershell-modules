using namespace System.Threading

function Reset-TestTally {
    <#
    .SYNOPSIS
        Empties the tally and returns the counts it held.
    .DESCRIPTION
        Not exported. Reading and emptying happen under one lock, so an
        assertion arriving from another runspace in between is neither lost
        nor counted twice. Emptying is what lets the next file run in the
        same session - from a prompt, say - start from nothing.
    .OUTPUTS
        An object: Passed and Failed, as they were.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Empties the in-memory tally of assertions; nothing outside the process changes.')]
    param()

    $tally = Get-TestTally
    [Monitor]::Enter($tally)
    try {
        $counts = [PSCustomObject]@{
            Passed = $tally.Passed
            Failed = $tally.Failed
        }

        $tally.Passed = 0
        $tally.Failed = 0
    }
    finally {
        [Monitor]::Exit($tally)
    }

    return $counts
}
