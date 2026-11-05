function Confirm-Proceed {
    <#
    .SYNOPSIS
        Returns $true when the run should continue - the final go/no-go gate.
    .DESCRIPTION
        Requires the word 'yes', in any casing and with or without spaces
        around it, rather than accepting anything truthy:
        a gate that a stray keypress can pass is not a gate.
        No retry - a wrong answer is a final no,
        reported through Write-Warn so it looks like every other warning.
        With nobody to ask - a session started with -NonInteractive - the
        prompt throws, so the gate stays shut rather than opening by default.
        The prompt is indented to the current Push-Indent level, like the
        lines printed around it.

        For a lighter, re-askable yes/no question, see Confirm-Input instead.
    .PARAMETER Action
        What is about to happen, completing "Type 'yes' to ...".
    .INPUTS
        None. The action is given with -Action.
    .OUTPUTS
        System.Boolean. True only for the answer yes.
    .EXAMPLE
        if (-not (Confirm-Proceed -Action 'delete the branch')) { return }

        Asks "Type 'yes' to delete the branch", and carries on only for yes.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Confirm-Input
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Action
    )

    try {
        $ErrorActionPreference = 'Stop'

        $indent = ' ' * (Get-Indent)
        $answer = Read-Host "${indent}Type 'yes' to $Action"
        if ("$answer".Trim() -eq 'yes') {
            return $true
        }

        Write-Warn 'Aborted by user'
        return $false
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
