using namespace System.Threading

function Add-TestResult {
    <#
    .SYNOPSIS
        Counts one case as passed or failed.
    .DESCRIPTION
        Not exported. Under a lock, since assertions can arrive from several
        runspaces at once.
    .PARAMETER Passed
        Whether the case passed.
    #>
    param(
        [Parameter(Mandatory)]
        [bool]$Passed
    )

    $key = if ($Passed) { 'Passed' } else { 'Failed' }
    $tally = Get-TestTally
    [Monitor]::Enter($tally)
    try {
        $tally[$key]++
    }
    finally {
        [Monitor]::Exit($tally)
    }
}
