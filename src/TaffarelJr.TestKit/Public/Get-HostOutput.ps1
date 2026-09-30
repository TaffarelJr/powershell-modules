using namespace System.Collections.Generic
using namespace System.Management.Automation

function Get-HostOutput {
    <#
    .SYNOPSIS
        Runs a script block and returns what it printed via Write-Host or
        Write-Information, one line per call.
    .DESCRIPTION
        Write-Host writes to the Information stream (6), not stdout,
        so it is invisible to normal output capture -
        6>&1 is what makes it visible,
        and the InformationRecord filter separates it
        from any genuine pipeline output the block also produced,
        which is discarded.

        $InformationPreference is set to Continue while the block runs - the
        variable the caller sees, wherever it lives, which the block and the
        caller's own functions read, and the global one, which module code
        reads - and put back after. A preference of Ignore would otherwise
        discard every line, so a check that nothing was printed would pass
        whatever the code did, and Stop would turn the first line into an
        error.

        An error the block throws is raised by this command, as a terminating
        error that carries the block's own exception.
    .PARAMETER ScriptBlock
        The code to run and capture the printed output of.
    .INPUTS
        None.
    .OUTPUTS
        System.String. The text of each call, one at a time. Wrap the call in
        @() to collect it as an array.
    .EXAMPLE
        $lines = @(Get-HostOutput { Write-Host 'a'; Write-Information 'b' })
        Assert-Equal -Expected @('a', 'b') -Actual $lines `
            -Message 'Both lines were printed'

        Captures what the block printed, one line per call, and checks it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Get-WarningOutput
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
        $callerVariable = $PSCmdlet.SessionState.PSVariable.Get('InformationPreference')
        $callerPreference = $callerVariable.Value
        $globalPreference = $global:InformationPreference
        $callerVariable.Value = [ActionPreference]::Continue
        $global:InformationPreference = [ActionPreference]::Continue
        try {
            $records = & $ScriptBlock 6>&1
        }
        finally {
            $callerVariable.Value = $callerPreference
            $global:InformationPreference = $globalPreference
        }

        $lines = [List[string]]::new()
        foreach ($record in $records) {
            if ($record -is [InformationRecord]) {
                $data = $record.MessageData
                if ($data -is [HostInformationMessage]) {
                    $lines.Add($data.Message)
                }
                else {
                    $lines.Add("$data")
                }
            }
        }

        return $lines.ToArray()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
