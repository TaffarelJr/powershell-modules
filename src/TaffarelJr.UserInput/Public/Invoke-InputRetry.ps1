function Invoke-InputRetry {
    <#
    .SYNOPSIS
        Runs a scriptblock up to a bounded number of attempts,
        retrying on a thrown failure and warning in between.
    .DESCRIPTION
        For composing Read-Input/Read-Secret with Assert-Input
        into a prompt that re-asks on a bad answer:

            Invoke-InputRetry -ScriptBlock {
                Read-Input -Prompt 'Repo name' | Assert-Input -Require
            }

        Bounded rather than infinite - a script whose input is redirected
        gets Read-Input's -Default back on every attempt
        (or an empty string with none set),
        which fails validation identically every time;
        an unbounded loop would retry that forever
        instead of eventually failing the run.

        The scriptblock's own exception
        propagates unchanged on the final attempt,
        so the caller sees exactly why the last answer was rejected
        rather than a generic retry-count message.
    .PARAMETER ScriptBlock
        The "try once" operation. A thrown exception counts as a failed attempt;
        anything else returned is the result.
    .PARAMETER MaxAttempt
        How many times to try before giving up. Defaults to 10.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [int]$MaxAttempt = 10
    )

    for ($attempt = 1; $attempt -le $MaxAttempt; $attempt++) {
        try {
            return (& $ScriptBlock)
        }
        catch {
            if ($attempt -eq $MaxAttempt) {
                throw
            }

            Write-Warn $_.Exception.Message
        }
    }
}
