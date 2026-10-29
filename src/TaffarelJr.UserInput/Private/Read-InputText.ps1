function Read-InputText {
    <#
    .SYNOPSIS
        Asks one question and returns what was typed, or $null when the input
        has ended.
    .DESCRIPTION
        Not exported. The asking half of Read-Input: prints the hint lines,
        builds the prompt from the question, the choices and the default, and
        reads one line with Read-Host. Nothing is trimmed and no default is
        applied, so a caller can tell a blank answer, which is an empty
        string, from the end of the input, which is $null.
    .PARAMETER Prompt
        The question shown to the user.
    .PARAMETER Default
        Shown as [Default]; it is not applied to the answer.
    .PARAMETER Choice
        Shown as (Choice1/Choice2); nothing enforces it.
    .PARAMETER Hint
        Lines printed immediately before the prompt, for context.
    .OUTPUTS
        The text Read-Host returned, or $null at the end of the input.
    #>
    param(
        [Parameter(Mandatory)]
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

    return Read-Host $label
}
