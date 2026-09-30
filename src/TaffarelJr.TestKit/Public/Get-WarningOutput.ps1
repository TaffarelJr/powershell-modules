using namespace System.Collections.Generic
using namespace System.Management.Automation

function Get-WarningOutput {
    <#
    .SYNOPSIS
        Runs a script block and returns the text of each warning it wrote,
        one line per warning.
    .DESCRIPTION
        Warnings are merged into the output stream (3>&1) to be seen, and
        separated from any genuine pipeline output the block also produced,
        which is discarded.

        $WarningPreference is set to Continue while the block runs - the
        variable the caller sees, wherever it lives, which the block and the
        caller's own functions read, and the global one, which module code
        reads - and put back after. No local copy is left in the caller's
        scope, so a later global change still reaches it.
        A preference of SilentlyContinue would otherwise hide every warning,
        so a check that there were none would pass whatever the code did,
        and Stop would turn the first warning into an error.

        An error the block throws is raised by this command, as a terminating
        error that carries the block's own exception.
    .PARAMETER ScriptBlock
        The code to run and capture the warnings of.
    .INPUTS
        None.
    .OUTPUTS
        System.String. The text of each warning, one at a time. Wrap the call
        in @() to collect it as an array.
    .EXAMPLE
        $warnings = @(Get-WarningOutput { Write-Warning 'careful' })
        Assert-Equal -Expected @('careful') -Actual $warnings `
            -Message 'The warning was written'

        Captures the text of each warning the block wrote, and checks it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Get-HostOutput
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $ErrorActionPreference = 'Stop'

        # Changing the variable the caller already sees, wherever it lives, never
        # leaves a local copy behind; an advanced caller's local cannot be removed.
        $callerVariable = $PSCmdlet.SessionState.PSVariable.Get('WarningPreference')
        $callerPreference = $callerVariable.Value
        $globalPreference = $global:WarningPreference
        $callerVariable.Value = [ActionPreference]::Continue
        $global:WarningPreference = [ActionPreference]::Continue
        try {
            $records = & $ScriptBlock 3>&1
        }
        finally {
            $callerVariable.Value = $callerPreference
            $global:WarningPreference = $globalPreference
        }

        $messages = [List[string]]::new()
        foreach ($record in $records) {
            if ($record -is [WarningRecord]) {
                $messages.Add($record.Message)
            }
        }

        return $messages.ToArray()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
