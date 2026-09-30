using namespace System.Management.Automation

function Get-HostOutput {
    <#
    .SYNOPSIS
        Runs a script block and returns what it printed via Write-Host,
        one array element per call.
    .DESCRIPTION
        Write-Host writes to the Information stream (6), not stdout,
        so it is invisible to normal output capture -
        6>&1 is what makes it visible,
        and the InformationRecord filter separates it
        from any genuine pipeline output the block also produced.
    .PARAMETER ScriptBlock
        The code to run and capture the printed output of.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $records = & $ScriptBlock 6>&1
    $lines = $records |
    Where-Object { $_ -is [InformationRecord] } |
    ForEach-Object { $_.MessageData.Message }

    return , @($lines)
}
