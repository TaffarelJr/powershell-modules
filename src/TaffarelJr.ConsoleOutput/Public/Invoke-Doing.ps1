using namespace System.Collections.Generic
using namespace System.Management.Automation

function Invoke-Doing {
    <#
    .SYNOPSIS
        Announces a step, runs a script block,
        and closes the line with how it went.
    .DESCRIPTION
        Writes the line Write-Doing writes, runs the block, and closes the
        line as Write-Done does: with the string the block returns as its
        last output, or "done" when it returns nothing, or no string. Any
        other output the block writes is passed on once the line is closed.
        With -KeepOutput, a block that ends normally closes the line with
        "done", and everything it writes is passed on, its last string
        included.

        Warnings the block writes are held back and written, in order, after
        the closed line, so none of them lands on the end of the open one.
        Only warnings are held: an error the block writes without throwing,
        verbose and information messages, and host output from other
        commands run on to the end of the open line, as they would after
        Write-Doing.

        A block that throws closes the line with "failed", in red, and the
        block's own exception is raised again, as a terminating error, even
        when the caller's -WarningAction Stop would turn a held warning into
        one. An error the block writes without throwing does not make the line
        say "failed", unless the caller's $ErrorActionPreference is Stop, which
        makes that error a throw.

        A block that leaves its caller's loop with break or continue closes
        the line with "stopped", in yellow, so no line is left open for the
        next write to run on to, and the break or continue goes on to the
        loop. Its warnings are still written after the line; the other output
        it had written is discarded, as it is when the block throws.

        A block that ends normally but holds a warning that the caller's
        -WarningAction Stop turns into an error also passes nothing on: the
        line is closed, the warning is written, and its error is raised.

        When the caller's $WhatIfPreference is on, the commands in the block
        print their own 'What if:' lines to the host, which would land on the
        end of the open line. The line is then written only after the block
        has run, and in one piece.

        The block runs in the caller's own scope, as ForEach-Object's does,
        so a variable it assigns is the caller's variable. A block that
        prints with this module's own writers closes the line first, and its
        outcome is then written as a line of its own, as Write-Done does when
        nothing is open. So is a block that opens a Doing line of its own:
        that line is ended, and the outcome never lands on it.
    .PARAMETER Text
        What the step is attempting, as Write-Doing takes it.
    .PARAMETER ScriptBlock
        The code that does the step. Its last output, when it is a string, is
        the outcome written at the end of the line, unless -KeepOutput is
        given.
    .PARAMETER KeepOutput
        Passes on everything the block writes, its last string included, and
        closes the line with "done" when the block ends normally. For a block
        whose output is data, such as lines read from a file, which must not
        lose its last item.
    .INPUTS
        None. The text and the script block are given with -Text and
        -ScriptBlock.
    .OUTPUTS
        System.Object. What the script block writes, one item at a time,
        leaving out its last output when that is the string that closed the
        line. Nothing comes out when the block throws, is left with break or
        continue, or holds a warning that -WarningAction Stop turns into an
        error.
    .EXAMPLE
        Invoke-Doing -Text 'Installing' -ScriptBlock {
            Install-Thing -Name 'one'
            'installed 1 package'
        }

        Prints "Installing ..." and, when the block ends, "installed 1
        package" on the same line.
    .EXAMPLE
        $lines = Invoke-Doing -Text 'Reading' -KeepOutput -ScriptBlock {
            Get-Content -Path 'settings.txt'
        }

        Prints "Reading ... done" and returns every line of the file.
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
        [scriptblock]$ScriptBlock,

        [switch]$KeepOutput
    )

    try {
        $ErrorActionPreference = 'Stop'

        # Under -WhatIf the block's commands print "What if:" lines to the host,
        # which would land on the open line: write the line after the block.
        $previewing = [bool]$PSCmdlet.GetVariableValue('WhatIfPreference')
        $line = 0
        if (-not $previewing) {
            $line = Open-DoingLine -Text $Text
        }

        $output = [List[object]]::new()
        $warnings = [List[string]]::new()
        $thrown = $null
        $outcome = 'Stopped'
        try {
            # Dot-sourced for the caller's scope, as in Invoke-Indented; 3>&1
            # collects the warnings so none lands on the end of the open line.
            . $ScriptBlock 3>&1 | ForEach-Object {
                if ($_ -is [WarningRecord]) {
                    $warnings.Add($_.Message)
                }
                else {
                    $output.Add($_)
                }
            }

            $outcome = 'Success'
        }
        catch {
            $outcome = 'Failure'
            $thrown = $_
        }
        finally {
            # Every exit closes the line here: break and continue leave the
            # block through neither path above, and skip everything after this.
            $wording = ''
            $last = $output.Count - 1
            $lastIsOutcome = $last -ge 0 -and $output[$last] -is [string]
            if ($outcome -eq 'Success' -and -not $KeepOutput -and $lastIsOutcome) {
                $wording = $output[$last]
                $output.RemoveAt($last)
            }

            if ($previewing) {
                $line = Open-DoingLine -Text $Text
            }

            Complete-OpenLine -Outcome $outcome -Text $wording -Line $line
            Write-WarningLine -Message $warnings.ToArray() -AfterFailure:($outcome -ne 'Success')
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
