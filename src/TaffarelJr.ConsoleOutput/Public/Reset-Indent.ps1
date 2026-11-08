using namespace System.Diagnostics.CodeAnalysis

function Reset-Indent {
    <#
    .SYNOPSIS
        Ends every indented region at once, putting the indent back to zero,
        and ends a line Write-Doing left open.
    .DESCRIPTION
        Takes off every level Push-Indent or Invoke-Indented added and not yet
        taken off, and ends a line Write-Doing left open, as Clear-Step does, so
        the next line starts on its own. A script that fails between a
        Push-Indent and its Pop-Indent leaves its levels behind for the rest of
        the session, and a step that failed leaves its Doing line open; a later
        run, or a catch that reports the failure, calls this to start again.
        Invoke-Indented puts the indent back by itself, even when its script
        block fails, so code that uses it does not need this. Called inside an
        Invoke-Indented block, it lasts only until the block ends: the block
        puts back the levels from before it and warns that it popped more than
        it pushed.
    .INPUTS
        None.
    .OUTPUTS
        None. The indent becomes zero and no line is left open; nothing is
        returned.
    .EXAMPLE
        try {
            Push-Indent
            Invoke-Build
        }
        catch {
            Reset-Indent
            Write-Failure "Build failed: $_"
        }

        Reports the failure at the outermost indent, whatever levels the
        failed build left behind.
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

    try {
        $ErrorActionPreference = 'Stop'

        Restore-IndentLevel
        Close-OpenLine
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
