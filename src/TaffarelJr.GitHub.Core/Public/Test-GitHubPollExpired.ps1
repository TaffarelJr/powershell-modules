function Test-GitHubPollExpired {
    <#
    .SYNOPSIS
        Reports whether a wait that polls gh has run out of time.
    .DESCRIPTION
        Read from the poll's monotonic clock, so a change of the system
        clock cannot end a wait early or stretch it.
    .PARAMETER Poll
        The state New-GitHubPoll returned.
    .INPUTS
        None
    .OUTPUTS
        System.Boolean
        $true once the elapsed time has reached the timeout.
    .EXAMPLE
        if (Test-GitHubPollExpired -Poll $poll) {
            throw [TimeoutException]::new('...')
        }

        Ends a wait whose -TimeoutSeconds has passed.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Poll
    )

    try {
        $ErrorActionPreference = 'Stop'

        return $Poll.Clock.Elapsed -ge $Poll.Timeout
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
