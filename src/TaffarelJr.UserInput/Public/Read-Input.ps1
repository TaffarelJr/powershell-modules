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
        resolves to -Default; anything else is trimmed and returned as-is.
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
    .EXAMPLE
        Read-Input -Prompt 'Repo name' | Assert-Input -Require
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [string]$Default = '',

        [string[]]$Choice,

        [string[]]$Hint
    )

    Write-InputHint -Hint $Hint

    $label = $Prompt
    if ($Choice) {
        $label += " ($($Choice -join '/'))"
    }

    if ($Default -ne '') {
        $label += " [$Default]"
    }

    $entered = Read-Host $label
    if ([string]::IsNullOrWhiteSpace($entered)) {
        return $Default
    }

    return $entered.Trim()
}
