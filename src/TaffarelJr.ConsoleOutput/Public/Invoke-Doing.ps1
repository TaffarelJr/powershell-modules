function Invoke-Doing {
    <#
    .SYNOPSIS
        Announces work, runs a script block, and ends the line with how it
        went.
    .DESCRIPTION
        Writes the line Show-Doing writes, runs the block, and ends the line
        as Show-Done does: with "done" when the block ends normally, with
        "failed" in red when it throws, and with "stopped" in yellow when it
        is left with break or continue. Whatever happens, the line is ended, so
        nothing is left open for the next write to run on to.

        What the block writes is passed on once the line has ended, not
        before, so none of it lands on the end of the open line. When the
        block throws, its output is not passed on, and the error reaches the
        caller after the line has ended. A break or continue goes on to the
        caller's loop after the line has ended.

        The block runs in the caller's own scope, as ForEach-Object's does, so
        a variable it assigns is the caller's variable. A block that writes
        with this module's own commands ends the line first, and its outcome
        is then written on a line of its own, as Show-Done does when no line
        is open.
    .PARAMETER Text
        What is about to be attempted, as Show-Doing takes it.
    .PARAMETER ScriptBlock
        The work to do.
    .INPUTS
        None. The text and the script block are given with -Text and
        -ScriptBlock.
    .OUTPUTS
        System.Object. What the script block writes, one item at a time. Nothing
        comes out when the block throws or is left with break or continue.
    .EXAMPLE
        Invoke-Doing 'Restoring' { Restore-Packages }

        Prints "Restoring ..." and, when the block ends, "done" on the same
        line.
    .EXAMPLE
        $lines = Invoke-Doing 'Reading' { Get-Content -Path 'settings.txt' }

        Prints "Reading ... done" and returns every line of the file.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Show-Doing
    .LINK
        Show-Done
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$ScriptBlock
    )

    Show-Doing -Text $Text

    $outcome = 'Stopped'
    try {
        # Dot-sourced: with & the block gets a scope of its own, and its
        # assignments would be lost when it ends.
        $output = @(. $ScriptBlock)
        $outcome = 'Success'
    }
    catch {
        $outcome = 'Failure'
        throw
    }
    finally {
        Show-Outcome -Outcome $outcome
    }

    Write-Output $output
}
