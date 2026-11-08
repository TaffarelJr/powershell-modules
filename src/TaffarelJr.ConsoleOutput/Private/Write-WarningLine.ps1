using namespace System.Management.Automation

function Write-WarningLine {
    <#
    .SYNOPSIS
        Writes one or more messages to the warning stream, after ending any
        line Write-Doing left open.
    .DESCRIPTION
        Not exported. A warning the caller's preference hides (SilentlyContinue
        or Ignore) leaves an open line alone, so a hidden warning does not split
        a Doing line from its outcome. A caller's -WarningAction Stop turns a
        warning into an error. When the command is already failing for a
        reason of its own, that reason must be the error the caller sees, so
        -AfterFailure writes every message and swallows the error a warning
        becomes.
    .PARAMETER Message
        The warnings, in order. An empty one is written as it is, as
        Write-Warning writes it.
    .PARAMETER AfterFailure
        The command is already failing, or is being left by break or continue:
        write every warning, and raise none.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Message,

        [switch]$AfterFailure
    )

    if ($Message.Count -eq 0) {
        return
    }

    if ($WarningPreference -notin 'SilentlyContinue', 'Ignore') {
        Close-OpenLine
    }

    foreach ($line in $Message) {
        try {
            Write-Warning -Message $line
        }
        catch [ActionPreferenceStopException] {
            if (-not $AfterFailure) {
                throw
            }
        }
    }
}
