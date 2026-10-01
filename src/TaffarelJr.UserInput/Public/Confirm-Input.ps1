function Confirm-Input {
    <#
    .SYNOPSIS
        Asks a plain yes/no question and returns a boolean.
    .DESCRIPTION
        Accepts y/yes/n/no, case-insensitively;
        a bare Enter accepts -Default.
        An unrecognized answer re-asks (see Invoke-InputRetry)
        rather than failing the run over a typo.

        For the stricter destructive-action gate -
        type the whole word "yes" or it is a final no -
        see Confirm-Proceed instead.
    .PARAMETER Prompt
        The question shown to the user.
    .PARAMETER Default
        Accepted on a bare Enter. Shown as (y/n) either way;
        pass this switch to default to yes instead of no.
    .EXAMPLE
        if (Confirm-Input -Prompt 'Install now?' -Default) { ... }
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [switch]$Default
    )

    $defaultAnswer = if ($Default) { 'y' } else { 'n' }

    $answer = Invoke-InputRetry -ScriptBlock {
        Read-Input -Prompt $Prompt -Choice 'y', 'n' -Default $defaultAnswer |
        Assert-Input -Choice 'y', 'yes', 'n', 'no' -Label $Prompt
    }

    return $answer -in @('y', 'yes')
}
