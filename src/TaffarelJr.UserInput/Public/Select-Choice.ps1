using namespace System.Management.Automation.Host

function Select-Choice {
    <#
    .SYNOPSIS
        Prompts for one choice from a numbered menu, returning the choice.
    .DESCRIPTION
        Built on the host's own $Host.UI.PromptForChoice,
        so arrow/number selection matches whatever the surrounding terminal
        already does for a built-in cmdlet's own confirmation prompts.
        For a choice validated from a typed or environment-sourced answer
        instead, use Assert-Input -Choice.
    .PARAMETER Prompt
        The question shown above the menu.
    .PARAMETER Option
        The choices offered, in the order shown.
    .PARAMETER Default
        Pre-selected choice, highlighted and accepted on a bare Enter.
        Omit it to require an explicit selection.
    .EXAMPLE
        Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private'
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [Parameter(Mandatory, Position = 1)]
        [string[]]$Option,

        [string]$Default
    )

    $descriptions = @($Option | ForEach-Object {
            [ChoiceDescription]::new($_)
        })

    $defaultIndex = if ($Default) {
        [array]::IndexOf($Option, $Default)
    }
    else {
        -1
    }

    $selected = $Host.UI.PromptForChoice('', $Prompt, $descriptions, $defaultIndex)
    return $Option[$selected]
}
