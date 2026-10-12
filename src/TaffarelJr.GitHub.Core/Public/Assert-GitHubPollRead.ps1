using namespace System.Collections

function Assert-GitHubPollRead {
    <#
    .SYNOPSIS
        Throws when one poll's gh read failed, so a wait ends at its first
        failure.
    .DESCRIPTION
        The failure policy every waiter of the TaffarelJr.GitHub.* modules
        shares: a read that failed ends the wait at once, whatever the
        failure - a 403, a rate limit, a server error, no network, no login.
        Waiting out a failure would only delay the error it ends in. What a
        wait does wait for is the thing it polls: between good reads it
        sleeps through Wait-GitHubPoll, up to its timeout.

        The message names what the poll was doing, the HTTP status when gh
        reported one (else gh's exit code), and gh's output below, with
        every credential a URL carries, and every GitHub token printed on
        its own, hidden.

        A caller that reads one particular failure as an answer - gh's "no
        checks reported", say - checks for it before calling this.
    .PARAMETER Result
        What Invoke-GitHubCommand -Tolerant returned for this poll.
    .PARAMETER Action
        What the poll does, as a phrase after "Could not" - such as "read
        workflow run 9".
    .INPUTS
        None
    .OUTPUTS
        None. A failed read throws.
    .EXAMPLE
        $poll = New-GitHubPoll -TimeoutSeconds $Timeout -PollSeconds 5
        $action = "read workflow run $RunId"
        while ($true) {
            $result = Invoke-GitHubCommand -Activity $activity `
                -Argument $arguments -Tolerant
            Assert-GitHubPollRead -Result $result -Action $action
            $run = ConvertFrom-GitHubJson -Line $result.Output
            if ($run.Status -eq 'completed') {
                break
            }
            if (Test-GitHubPollExpired -Poll $poll) {
                $subject = "Workflow run $RunId was still running after" +
                " $Timeout s."
                $message = Get-GitHubTimeoutMessage -Subject $subject
                throw [TimeoutException]::new($message)
            }
            Wait-GitHubPoll -Poll $poll | Out-Null
        }

        Polls until the run completes. A failed read throws at once, as
        "Could not read workflow run 9 (HTTP 403):" with gh's reason below.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [IDictionary]$Result,

        [Parameter(Mandatory)]
        [string]$Action
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($Result['Ok']) {
            return
        }

        throw (Format-GitHubFailure -Subject "Could not $Action" -Result $Result)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
