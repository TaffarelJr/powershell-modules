function Invoke-WithTally {
    <#
    .SYNOPSIS
        Runs a script block against a tally set to the given counts, then
        puts the real tally back.
    .DESCRIPTION
        Not exported - a test-only fixture. For testing what Complete-TestRun
        and Skip-TestRun do with a tally, in-process, without the file under
        test being the one that produced it.
    .PARAMETER Passed
        The passed count the block sees.
    .PARAMETER Failed
        The failed count the block sees.
    .PARAMETER ScriptBlock
        The code to run. Whatever it outputs is returned.
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Passed,

        [Parameter(Mandatory)]
        [int]$Failed,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $module = Get-Module TaffarelJr.TestKit
    $tally = & $module { Get-TestTally }
    $passedBefore = $tally.Passed
    $failedBefore = $tally.Failed
    $tally.Passed = $Passed
    $tally.Failed = $Failed
    try {
        return & $ScriptBlock
    }
    finally {
        $tally.Passed = $passedBefore
        $tally.Failed = $failedBefore
    }
}

function Get-AssertionVerdict {
    <#
    .SYNOPSIS
        Runs a script block holding assertions, and reports what they
        counted and printed - without letting them count toward this file's
        tally.
    .DESCRIPTION
        Not exported - a test-only fixture. An assertion that is meant to
        fail would otherwise fail the file that is testing it. The tally is
        put back to what it was before the block ran, even when it throws.
    .PARAMETER ScriptBlock
        The code holding the assertions.
    .OUTPUTS
        An object with Passed and Failed (what the block added to the
        tally) and Lines (every line it printed).
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $module = Get-Module TaffarelJr.TestKit
    $tally = & $module { Get-TestTally }
    $passedBefore = $tally.Passed
    $failedBefore = $tally.Failed
    try {
        $lines = @(Get-HostOutput -ScriptBlock $ScriptBlock)
        $passed = $tally.Passed - $passedBefore
        $failed = $tally.Failed - $failedBefore
    }
    finally {
        $tally.Passed = $passedBefore
        $tally.Failed = $failedBefore
    }

    return [PSCustomObject]@{
        Passed = $passed
        Failed = $failed
        Lines  = $lines
    }
}

function Assert-ThatOrThrow {
    <#
    .SYNOPSIS
        Records a case like Assert-That, and also throws when it fails.
    .DESCRIPTION
        Not exported - a test-only fixture. These files test the tally that
        reports on them, so a kit that counted a failure as a pass would
        report itself green. Throwing fails the file through its exit code,
        which does not depend on the tally.
    .PARAMETER Condition
        The condition being asserted.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    #>
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Assert-That -Condition $Condition -Message $Message
    if (-not $Condition) {
        throw "A check of the kit's own counting failed: $Message"
    }
}

function Assert-Verdict {
    <#
    .SYNOPSIS
        Asserts what one assertion counted and printed, from its verdict.
    .DESCRIPTION
        Not exported - a test-only fixture. The count is checked through
        Assert-ThatOrThrow, so it fails the file even when the tally is
        what is broken.
    .PARAMETER Verdict
        What Get-AssertionVerdict returned for a block holding one
        assertion.
    .PARAMETER Outcome
        Whether the assertion should have counted one pass or one failure.
    .PARAMETER LineLike
        A case-sensitive wildcard pattern for the one line it should have
        printed.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Verdict,

        [Parameter(Mandatory)]
        [ValidateSet('Passed', 'Failed')]
        [string]$Outcome,

        [Parameter(Mandatory)]
        [string]$LineLike,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $expectedPassed = if ($Outcome -eq 'Passed') { 1 } else { 0 }
    $counted = $Verdict.Passed -eq $expectedPassed -and $Verdict.Failed -eq 1 - $expectedPassed
    Assert-ThatOrThrow -Condition $counted -Message "$Message - counted one $Outcome case"

    $printed = $Verdict.Lines.Count -eq 1 -and $Verdict.Lines[0] -clike $LineLike
    Assert-That -Condition $printed -Message "$Message - printed one line like '$LineLike'"
}
