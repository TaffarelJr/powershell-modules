function Read-Input {
    <#
    .SYNOPSIS
        Prompts once for a plain-text value.
    .DESCRIPTION
        No validation and no retry - this only asks.
        Pass the result to Assert-Input,
        directly or through the pipeline, to check it;
        wrap the pair in Invoke-InputRetry to re-ask on a bad answer.

        A blank or EOF answer ([string]::IsNullOrWhiteSpace)
        resolves to -Default; anything else is returned trimmed.
        A session started with -NonInteractive cannot be asked at all, and
        Read-Host's own error says so - see Test-InteractiveHost for checking
        first. That error is a terminating error for the call.
    .PARAMETER Prompt
        The question shown to the user.
    .PARAMETER Default
        Shown as [Default] and accepted on a bare Enter.
    .PARAMETER Choice
        Shown as (Choice1/Choice2) so the user knows what is expected.
        Cosmetic only - nothing here enforces it;
        pass the same list to Assert-Input -Choice
        to actually validate the answer.
    .PARAMETER Hint
        Lines printed immediately before the prompt, for context.
    .INPUTS
        None. The question is given with -Prompt.
    .OUTPUTS
        System.String. The answer, trimmed, or -Default for a blank one.
    .EXAMPLE
        Read-Input -Prompt 'Repo name' | Assert-Input -Require

        Asks for a name and throws when the answer is empty.
    .EXAMPLE
        Read-Input -Prompt 'Visibility' -Choice 'Public', 'Private' `
            -Default 'Private'

        Asks "Visibility (Public/Private) [Private]", and a bare Enter
        answers Private.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Assert-Input
    .LINK
        Read-Secret
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [string]$Default = '',

        [string[]]$Choice,

        [string[]]$Hint
    )

    try {
        $ErrorActionPreference = 'Stop'

        $entered = Read-InputText -Prompt $Prompt -Default $Default -Choice $Choice -Hint $Hint
        if ([string]::IsNullOrWhiteSpace($entered)) {
            return $Default
        }

        return $entered.Trim()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
