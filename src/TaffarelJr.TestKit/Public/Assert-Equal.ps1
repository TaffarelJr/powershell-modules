function Assert-Equal {
    <#
    .SYNOPSIS
        Asserts two values are equal, printing both on failure.
    .DESCRIPTION
        An array on either side is compared element-by-element, in order.
        A bare -eq would instead treat an array on the left as a filter
        over its own elements rather than as one value to compare - so
        two identical arrays would silently never match.
    .PARAMETER Expected
        The value the case requires.
    .PARAMETER Actual
        The value produced by the code under test.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    #>
    param(
        $Expected,
        $Actual,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $equal = if ($Expected -is [array] -or $Actual -is [array]) {
        $null -eq (Compare-Object -ReferenceObject @($Expected) -DifferenceObject @($Actual) -SyncWindow 0)
    }
    else {
        $Expected -eq $Actual
    }

    if ($equal) {
        Assert-That -Condition $true -Message $Message
    }
    else {
        Assert-That -Condition $false -Message "$Message (expected [$Expected], got [$Actual])"
    }
}
