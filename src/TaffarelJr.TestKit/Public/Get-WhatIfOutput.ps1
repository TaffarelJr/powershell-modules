using namespace System.Collections.Generic
using namespace System.IO

function Get-WhatIfOutput {
    <#
    .SYNOPSIS
        Runs a script block and returns what it wrote to the pipeline and the
        'What if:' lines it printed, apart.
    .DESCRIPTION
        ShouldProcess prints its 'What if:' line straight to the host, on no
        stream a redirection can catch, so the block runs under a transcript
        of its own, in a new file in the temp folder, and the lines are read
        back from it. Every host line that starts with 'What if: ' counts,
        whoever printed it, and only in that exact case. The lines still
        show on the console as usual.

        A message about an operation and a target ("Performing the operation
        ... on target ...") whose target holds line breaks comes back as one
        entry, its lines joined with a line feed. That message is told by
        its last line ending in a quote and a period; any other message is
        its first line alone.

        The transcript is stopped and its file deleted whether or not the
        block throws. What the block throws is raised by this command, as a
        terminating error that carries the block's own exception, unless
        -CaptureError is given.

        A transcript that is already running keeps running: the capture's
        own is started inside it and is the only one stopped, and the outer
        one records the 'What if:' lines as well. The block must not stop a
        transcript itself.

        The capture's own transcript and file ignore $WhatIfPreference and
        $ConfirmPreference, so a block that tests a function under a session
        set to preview or to ask is captured all the same; the block itself
        still follows them.
    .PARAMETER ScriptBlock
        The code to run, normally one call given -WhatIf. It sees the
        caller's variables and functions.
    .PARAMETER CaptureError
        Returns what the block threw as the result's Error instead of
        throwing it, alongside the 'What if:' lines and output written before
        the throw. Without it, Error is always $null.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. One object with Output,
        the objects the block wrote to the pipeline
        (an array, empty when there were none); Messages, each 'What if:'
        message in the order printed (an array of strings, empty when there
        were none); and Error, the ErrorRecord the block threw when
        -CaptureError is given, otherwise $null.
    .EXAMPLE
        $run = Get-WhatIfOutput { Remove-Item -LiteralPath $path -WhatIf }
        Assert-Equal -Expected 0 -Actual $run.Output.Count `
            -Message 'It returns nothing'
        Assert-That -Condition ($run.Messages.Count -eq 1) `
            -Message 'It says what it would do'

        Checks that a call under -WhatIf returns nothing and says what it
        would do.
    .EXAMPLE
        $run = Get-WhatIfOutput -CaptureError {
            Install-Thing -Name 'Missing' -WhatIf
        }
        Assert-Equal -Expected 'Thing not found.' `
            -Actual $run.Error.Exception.Message `
            -Message 'It still fails'

        Checks the failure and the 'What if:' lines printed before it, from
        one run.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Get-HostOutput
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [switch]$CaptureError
    )

    try {
        $ErrorActionPreference = 'Stop'

        $path = Join-Path ([Path]::GetTempPath()) "testkit-whatif-$([Guid]::NewGuid()).txt"
        $output = [List[object]]::new()
        $thrown = $null
        Start-Transcript -LiteralPath $path -UseMinimalHeader -WhatIf:$false -Confirm:$false | Out-Null
        try {
            try {
                & $ScriptBlock | ForEach-Object { $output.Add($_) }
            }
            catch {
                if (-not $CaptureError) {
                    throw
                }
                $thrown = $_
            }
            finally {
                Stop-Transcript -WhatIf:$false -Confirm:$false | Out-Null
            }

            $lines = @(Get-Content -LiteralPath $path)
        }
        finally {
            Remove-Item -LiteralPath $path -Force -WhatIf:$false -Confirm:$false
        }

        $ordinal = [StringComparison]::Ordinal
        $messages = [List[string]]::new()
        for ($index = 0; $index -lt $lines.Count; $index++) {
            $message = $lines[$index]
            if (-not $message.StartsWith('What if: ', $ordinal)) {
                continue
            }

            # Such a message ends its last line with a quote and a period,
            # which is how a target that holds line breaks is seen to span several.
            $standard = $message.StartsWith('What if: Performing the operation "', $ordinal)
            if ($standard -and -not $message.EndsWith('".', $ordinal)) {
                $last = $index + 1
                while ($last -lt $lines.Count -and -not $lines[$last].EndsWith('".', $ordinal)) {
                    $last++
                }

                if ($last -lt $lines.Count) {
                    $message = $lines[$index..$last] -join "`n"
                    $index = $last
                }
            }

            $messages.Add($message)
        }

        return [PSCustomObject]@{
            Output   = $output.ToArray()
            Messages = $messages.ToArray()
            Error    = $thrown
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
