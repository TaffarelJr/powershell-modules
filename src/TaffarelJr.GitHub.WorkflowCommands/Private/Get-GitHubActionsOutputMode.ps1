function Get-GitHubActionsOutputMode {
    <#
    .SYNOPSIS
        Tells how a workflow command reaches the step's log from here.
    .DESCRIPTION
        Not exported. Decided per process first, then per host:

        Host - the process is a PowerShell server (a background job, an
        out-of-process runspace, remoting), whose standard output carries
        its session, so every runspace in it, a nested thread job included,
        goes through the host and the parent shows the line. So does a host
        that is no step process at all, such as an editor's.

        Console - the console host's own runspace in the step's process,
        where the process's standard output is the log.

        Runspace - any other runspace in that same process (a thread job, a
        ForEach-Object -Parallel block), where standard output is the log
        too, but the console host may be part-way through a line of its
        own. A thread job started with -StreamingHost shares the console
        host, so its host is named ConsoleHost too; only its runspace tells
        it apart.

        Write-GitHubActionsLine asks this, rather than deciding itself, so a
        test can see what it does in each case.
    .PARAMETER HostName
        The host's name. Defaults to this runspace's.
    .PARAMETER OwnRunspace
        Whether this runspace is the console host's own. Defaults to whether
        it is, in the console host.
    .PARAMETER ServerProcess
        Whether the process is a PowerShell server. Defaults to what
        Test-GitHubActionsServerProcess finds for this process.
    .OUTPUTS
        Console, Runspace, or Host.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$HostName = $Host.Name,

        [bool]$OwnRunspace = (
            $Host.Name -eq 'ConsoleHost' -and
            [object]::ReferenceEquals($Host.Runspace, [runspace]::DefaultRunspace)),

        [bool]$ServerProcess = (Test-GitHubActionsServerProcess)
    )

    if ($ServerProcess) {
        return 'Host'
    }

    if ($HostName -eq 'ConsoleHost' -and $OwnRunspace) {
        return 'Console'
    }

    if ($HostName -in 'ConsoleHost', 'Default Host') {
        return 'Runspace'
    }

    return 'Host'
}
