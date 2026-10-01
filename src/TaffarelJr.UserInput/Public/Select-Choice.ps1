using namespace System.Collections.Generic

function Select-Choice {
    <#
    .SYNOPSIS
        Prompts for one choice from a numbered menu, returning the choice.
    .DESCRIPTION
        Prints the options as a numbered list and asks for the number, or the
        option's own text in any casing. A bare Enter takes -Default. Anything
        else is explained and asked again, through Invoke-InputRetry, so the
        menu is shown again too. Input that has ended is the exception: it
        takes -Default, and with none the call fails at once, since asking
        again would read nothing new.

        Built from Read-Input rather than the host's own
        $Host.UI.PromptForChoice: with input redirected from a pipe or a file,
        that fails with a null reference error for any answer but a full
        label, and a test has no way to answer it. This works in any host,
        and answers can be piped in.

        An option whose text is itself a number is reached by its number
        first. An option with spaces around it, or one listed twice ignoring
        case, is refused, since typing it could not pick it. For a choice
        validated from a typed or environment-sourced answer instead, use
        Assert-Input -Choice.

        A menu that cannot be offered - a mistake in -Option or -Default - and
        a prompt that cannot be asked, or is still answered wrongly on the
        last attempt, are each a terminating error for the call.
    .PARAMETER Prompt
        The question shown below the menu.
    .PARAMETER Option
        The choices offered, in the order shown.
    .PARAMETER Default
        Pre-selected choice, accepted on a bare Enter and shown by its number.
        Omit it to require an explicit selection. Must be one of -Option, in
        any casing.
    .PARAMETER Hint
        Lines printed before the menu, for context.
    .INPUTS
        None. The question and the options are given with -Prompt and -Option.
    .OUTPUTS
        System.String. The chosen option, exactly as given in -Option.
    .EXAMPLE
        Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private' `
            -Default 'Private'

        Shows a two-line menu, and a bare Enter picks Private.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Read-Input
    .LINK
        Assert-Input
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [Parameter(Mandatory, Position = 1)]
        [string[]]$Option,

        [string]$Default,

        [string[]]$Hint
    )

    try {
        $ErrorActionPreference = 'Stop'

        $seen = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase)
        foreach ($item in $Option) {
            if ($item -cne $item.Trim()) {
                $record = New-CallMistakeError `
                    -Message "-Option '$item' has spaces around it, so typing it could never match; remove them" `
                    -ErrorId 'OptionPadded' `
                    -TargetObject $item
                $PSCmdlet.ThrowTerminatingError($record)
            }

            if (-not $seen.Add($item)) {
                $record = New-CallMistakeError `
                    -Message ("-Option lists '$item' more than once, ignoring case, " +
                        'so typing it could not tell them apart') `
                    -ErrorId 'OptionDuplicated' `
                    -TargetObject $item
                $PSCmdlet.ThrowTerminatingError($record)
            }
        }

        $defaultNumber = ''
        if ($Default) {
            $index = -1
            for ($i = 0; $i -lt $Option.Count; $i++) {
                if ($Option[$i] -eq $Default) {
                    $index = $i
                    break
                }
            }

            if ($index -lt 0) {
                $record = New-CallMistakeError `
                    -Message "-Default '$Default' is not one of the options: $($Option -join ', ')" `
                    -ErrorId 'DefaultNotAnOption' `
                    -TargetObject $Default
                $PSCmdlet.ThrowTerminatingError($record)
            }

            $defaultNumber = [string]($index + 1)
        }

        $menu = for ($i = 0; $i -lt $Option.Count; $i++) {
            "$($i + 1). $($Option[$i])"
        }

        $shown = @($menu)
        if ($null -ne $Hint) {
            $shown = $Hint + $shown
        }

        return Invoke-InputRetry -ArgumentList $Prompt, $defaultNumber, $shown, $Option -ScriptBlock {
            param($question, $defaultNumber, $shown, $options)
            $typed = Read-InputText -Prompt $question -Default $defaultNumber -Hint $shown
            $answer = if ([string]::IsNullOrWhiteSpace($typed)) { $defaultNumber } else { $typed.Trim() }
            $number = 0
            if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $options.Count) {
                return $options[$number - 1]
            }

            $byText = @($options -eq $answer)
            if ($byText) {
                return $byText[0]
            }

            $message = "The answer must be a number from 1 to $($options.Count), " +
                "or one of: $($options -join ', ')"
            if ($null -eq $typed) {
                throw (New-CallMistakeError -Message $message -ErrorId 'EndOfInput' -TargetObject $null)
            }

            throw $message
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
