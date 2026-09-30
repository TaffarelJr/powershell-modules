function Assert-Throws {
    <#
    .SYNOPSIS
        Asserts a script block throws.
    .PARAMETER ScriptBlock
        The code expected to throw.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        # Discarded, not just unused:
        # a block that returns a value instead of throwing
        # would otherwise leak that value into the caller's own output stream.
        $null = & $ScriptBlock
        Assert-That -Condition $false -Message "$Message (did not throw)"
    }
    catch {
        Assert-That -Condition $true -Message $Message
    }
}
