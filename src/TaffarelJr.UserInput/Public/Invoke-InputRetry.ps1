using namespace System.Management.Automation

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

        Bounded rather than infinite - a script whose input is closed
        gets Read-Input's -Default back on every attempt
        (or an empty string with none set),
        which fails validation identically every time;
        an unbounded loop would retry that forever
        instead of eventually failing the run.

        Some failures are never retried, because another attempt cannot
        change them: one on a session with nobody to re-ask
        (see Test-InteractiveHost), and one that is a mistake in how the block
        is written rather than in an answer: a command that does not exist,
        a parameter that is unknown, ambiguous, given twice, missing its
        value, or mandatory and left out, a positional argument with nowhere
        to go, or one of this module's own call mistakes, such as a pattern
        that is not a regular expression. The end of the input, which
        Select-Choice reports, is not retried either: asking again reads
        nothing new. Anything else the block throws is
        retried, including an answer that fails a conversion such as [int]
        or a parameter's validation such as [ValidateRange].

        The scriptblock's own exception
        propagates unchanged on the final attempt,
        so the caller sees exactly why the last answer was rejected
        rather than a generic retry-count message. It arrives as a
        terminating error for the call, with the same message and exception.

        That message is also the text of each warning between attempts, and
        it can quote the answer: a conversion such as [int] of a secret from
        Read-Secret can echo it when it fails. Do the conversion outside the
        block, or make the block throw a message of its own.
    .PARAMETER ScriptBlock
        The "try once" operation. A thrown exception counts as a failed attempt;
        anything else returned is the result.
    .PARAMETER ArgumentList
        Values handed to the scriptblock's own parameters, in order, on every
        attempt, so the block need not read variables from the caller's scope.
    .PARAMETER MaxAttempt
        How many times to try before giving up. Defaults to 10.
    .INPUTS
        None. The script block is given with -ScriptBlock.
    .OUTPUTS
        System.Object. Whatever the script block returns on the attempt that
        succeeds.
    .EXAMPLE
        Invoke-InputRetry -ArgumentList 'Port' -ScriptBlock {
            param($prompt)
            [int](Read-Input -Prompt $prompt)
        }

        Asks for a port number, and asks again after an answer that is not one.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Read-Input
    .LINK
        Assert-Input
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [object[]]$ArgumentList = @(),

        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxAttempt = 10
    )

    try {
        $ErrorActionPreference = 'Stop'

        for ($attempt = 1; $attempt -le $MaxAttempt; $attempt++) {
            try {
                return (& $ScriptBlock @ArgumentList)
            }
            catch {
                $errorId = $_.FullyQualifiedErrorId
                $mistypedCall = $_.Exception -is [ParameterBindingException] -and
                    $_.Exception.ErrorId -in $script:MistypedBindingErrorId
                $namedMistake = @($script:CallMistakeErrorId |
                        Where-Object { $errorId -eq $_ -or $errorId.StartsWith("$_,") }).Count -gt 0
                $callMistake = $mistypedCall -or
                    $_.Exception -is [CommandNotFoundException] -or
                    $namedMistake
                if ($attempt -eq $MaxAttempt -or $callMistake -or -not (Test-InteractiveHost)) {
                    throw
                }

                Write-Warn $_.Exception.Message
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
