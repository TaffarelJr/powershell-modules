function New-GitHubPoll {
    <#
    .SYNOPSIS
        Starts the clock for one wait that polls gh.
    .DESCRIPTION
        The state Wait-GitHubPoll and Test-GitHubPollExpired share for one
        wait. The time is read from a Stopwatch, a monotonic clock, so a
        change of the system clock or of daylight saving time neither
        stretches nor cuts a wait.

        Each read goes through Assert-GitHubPollRead, which ends the wait
        at its first failure: the clock bounds only how long the wait
        lasts while gh answers and the thing polled is not ready yet.
    .PARAMETER TimeoutSeconds
        How long the whole wait may take.
    .PARAMETER PollSeconds
        How many seconds to wait between polls.
    .INPUTS
        None
    .OUTPUTS
        System.Collections.Hashtable
        Clock (the running Stopwatch - anything with an Elapsed [TimeSpan]
        will do, for a test), Timeout ([TimeSpan]), PollSeconds, and Sleep
        (a script block taking milliseconds, which a test may replace so
        nothing really sleeps).
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

        Polls until the run completes, throws at once when a read fails,
        and throws a TimeoutException at the deadline: "Workflow run 7 was
        still running after 30 s. Give a longer -TimeoutSeconds to wait
        more."
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Builds the poll state in memory; nothing outside the process changes.')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory)]
        [ValidateRange(1, 3600)]
        [int]$PollSeconds
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        return @{
            Clock       = [System.Diagnostics.Stopwatch]::StartNew()
            Timeout     = [TimeSpan]::FromSeconds($TimeoutSeconds)
            PollSeconds = $PollSeconds
            Sleep       = { param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
