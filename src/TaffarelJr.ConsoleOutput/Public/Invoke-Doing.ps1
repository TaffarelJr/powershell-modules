using namespace System.Collections.Generic
using namespace System.Management.Automation

function Invoke-Doing {
    <#
    .SYNOPSIS
        Announces a step, runs a script block, and closes the line with how it
        went.
    .DESCRIPTION
        Writes the line Write-Doing writes, runs the block, and closes the
        line as Write-Done does: with the string the block returns as its
        last output, or "done" when it returns nothing, or no string. Any
        other output the block writes is passed on once the line is closed.

        Warnings the block writes are held back and written, in order, after
        the closed line, so none of them lands on the end of the open one.

        A block that throws closes the line with "failed", in red, and the
        error is raised again, as it was thrown.

        When the caller's $WhatIfPreference is on, the commands in the block
        print their own 'What if:' lines to the host, which would land on the
        end of the open line. The line is then written only after the block
        has run, and in one piece.

        The block runs in the caller's own scope, as ForEach-Object's does,
        so a variable it assigns is the caller's variable. A block that
        prints with this module's own writers closes the line first, and its
        outcome is then written as a line of its own, as Write-Done does when
        nothing is open.
    .PARAMETER Text
        What the step is attempting, as Write-Doing takes it.
    .PARAMETER ScriptBlock
        The code that does the step. Its last output, when it is a string, is
        the outcome written at the end of the line.
    .INPUTS
        None. The text and the script block are given with -Text and
        -ScriptBlock.
    .OUTPUTS
        System.Object. What the script block writes, one item at a time,
        leaving out its last output when that is the string that closed the
        line.
    .EXAMPLE
        Invoke-Doing -Text 'Installing' -ScriptBlock {
            Install-Thing -Name 'one'
            'installed 1 package'
        }

        Prints "Installing ..." and, when the block ends, "installed 1
        package" on the same line.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Doing
    .LINK
        Write-Done
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

    try {
        $ErrorActionPreference = 'Stop'

        $previewing = [bool]$PSCmdlet.GetVariableValue('WhatIfPreference')
        if (-not $previewing) {
            Write-Doing -Text $Text
        }

        $output = [List[object]]::new()
        $warnings = [List[string]]::new()
        $thrown = $null
        try {
            . $ScriptBlock 3>&1 | ForEach-Object {
                if ($_ -is [WarningRecord]) {
                    $warnings.Add($_.Message)
                }
                else {
                    $output.Add($_)
                }
            }
        }
        catch {
            $thrown = $_
        }

        if ($previewing) {
            Write-Doing -Text $Text
        }

        if ($null -ne $thrown) {
            if ($script:LineOpen) {
                $script:LineOpen = $false
                Write-MessageLine -Lead ' ' -Continuation $script:OpenLineContinuation `
                    -Text 'failed' -Color Red
            }
            else {
                Write-Failure -Text 'failed'
            }
        }
        else {
            $outcome = ''
            $last = $output.Count - 1
            if ($last -ge 0 -and $output[$last] -is [string]) {
                $outcome = $output[$last]
                $output.RemoveAt($last)
            }

            Write-Done -Text $outcome
        }

        foreach ($message in $warnings) {
            Write-Warning -Message $message
        }

        if ($null -ne $thrown) {
            throw $thrown
        }

        return $output.ToArray()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
