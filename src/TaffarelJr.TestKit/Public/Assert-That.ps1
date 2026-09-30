function Assert-That {
    <#
    .SYNOPSIS
        Records one pass/fail case against a boolean condition.
    .PARAMETER Condition
        The condition being asserted.
        Evaluate it before calling, not inline,
        so the failure message can describe what was checked.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    #>
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Condition) {
        $script:PassCount++
        Write-Host "  ok - $Message" -ForegroundColor Green
    }
    else {
        $script:FailCount++
        Write-Host "  FAIL - $Message" -ForegroundColor Red
    }
}
