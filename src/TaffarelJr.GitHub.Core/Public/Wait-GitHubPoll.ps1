function Wait-GitHubPoll {
    <#
    .SYNOPSIS
        Sleeps until the next poll is due, never past the wait's deadline.
    .DESCRIPTION
        The pause is the poll interval, clamped to the time left, so the
        last poll runs at the deadline rather than an interval later. A
        deadline already passed does not sleep at all.
    .PARAMETER Poll
        The state New-GitHubPoll returned. Its Sleep script block does the
        sleeping.
    .INPUTS
        None
    .OUTPUTS
        System.Int32
        The milliseconds slept.
    .EXAMPLE
        Wait-GitHubPoll -Poll $poll | Out-Null

        Sleeps PollSeconds between two polls of a wait New-GitHubPoll
        started, or less when the timeout comes first.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Poll
    )

    try {
        $ErrorActionPreference = 'Stop'

        $remaining = ($Poll.Timeout - $Poll.Clock.Elapsed).TotalMilliseconds
        $pause = [int][Math]::Max(0, [Math]::Ceiling([Math]::Min($Poll.PollSeconds * 1000.0, $remaining)))
        if ($pause -gt 0) {
            & $Poll.Sleep $pause
        }

        return $pause
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
