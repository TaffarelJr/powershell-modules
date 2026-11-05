function Confirm-Input {
    <#
    .SYNOPSIS
        Asks a plain yes/no question and returns a boolean.
    .DESCRIPTION
        Accepts y/yes/n/no, case-insensitively;
        a bare Enter accepts -Default.
        An unrecognized answer re-asks (see Invoke-InputRetry)
        rather than failing the run over a typo.

        With the input closed, every answer is a bare Enter, so the result is
        -Default. Leave the default at no for anything that changes the
        machine or cannot be undone.

        For the stricter destructive-action gate -
        type the whole word "yes" or it is a final no -
        see Confirm-Proceed instead.

        A prompt that cannot be asked, or that is still answered wrongly on
        the last attempt, is a terminating error for the call.
    .PARAMETER Prompt
        The question shown to the user.
    .PARAMETER Default
        Accepted on a bare Enter. Shown as (y/n) [n], or as (y/n) [y] with
        this switch, which makes a bare Enter a yes.
    .PARAMETER Hint
        Lines printed immediately before the question, for context.
    .INPUTS
        None. The question is given with -Prompt.
    .OUTPUTS
        System.Boolean. True for a yes, false for a no.
    .EXAMPLE
        if (Confirm-Input -Prompt 'Install the missing modules now?') { ... }

        A bare Enter, or input that is closed, answers no.
    .EXAMPLE
        if (Confirm-Input -Prompt 'Show the full log?' -Default) { ... }

        A bare Enter answers yes.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Confirm-Proceed
    .LINK
        Invoke-InputRetry
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [switch]$Default,

        [string[]]$Hint
    )

    try {
        $ErrorActionPreference = 'Stop'

        $defaultAnswer = if ($Default) { 'y' } else { 'n' }

        $answer = Invoke-InputRetry -ArgumentList $Prompt, $defaultAnswer, $Hint -ScriptBlock {
            param($question, $defaultAnswer, $hint)
            $typed = Read-Input -Prompt $question -Choice 'y', 'n' -Default $defaultAnswer -Hint $hint
            Assert-Input -Value $typed -Choice 'y', 'yes', 'n', 'no' -Label 'The answer'
        }

        return $answer -in @('y', 'yes')
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
