using namespace System.Diagnostics.CodeAnalysis

function Reset-Indent {
    <#
    .SYNOPSIS
        Ends every indented region at once, putting the indent back to zero.
    .DESCRIPTION
        Takes off every level Push-Indent or Invoke-Indented added and not yet
        taken off. A script that fails between a Push-Indent and its
        Pop-Indent leaves its levels behind for the rest of the session; a
        later run, or a catch that reports the failure, calls this to start
        again. Invoke-Indented puts the indent back by itself, even when its
        script block fails, so code that uses it does not need this. Called
        inside an Invoke-Indented block, it leaves that block's own
        Pop-Indent with nothing to pop, so the pop warns.
    .INPUTS
        None.
    .OUTPUTS
        None. The indent becomes zero; nothing is returned.
    .EXAMPLE
        try {
            Push-Indent
            Invoke-Build
        }
        catch {
            Reset-Indent
            throw
        }

        Puts the indent back to zero before the error reaches the caller,
        whatever levels the failed build left behind.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Push-Indent
    .LINK
        Invoke-Indented
    #>
    [CmdletBinding()]
    [SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Changes the indentation this module keeps in memory; nothing outside the process changes.')]
    param()

    $script:IndentStack.Clear()
    $script:IndentSize = 0
}
