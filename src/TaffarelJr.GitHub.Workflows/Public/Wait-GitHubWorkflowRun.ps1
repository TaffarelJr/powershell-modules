function Wait-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Waits for a workflow run to finish, then returns it.
    .DESCRIPTION
        Polls gh directly for the run's status rather than delegating to
        gh run watch, which has no timeout of its own and does not work
        with a fine-grained personal access token - that token type
        cannot carry the checks:read permission gh run watch needs.

        The timeout is measured on a monotonic clock, so a change of the
        system clock or of daylight saving time neither stretches nor cuts
        it. The last sleep ends at the deadline rather than a whole poll
        interval later, and the run is read once more there. A run still
        going then throws a TimeoutException naming its last status.

        A poll whose gh read fails ends the wait at once, whatever the
        failure - a 403, a rate limit, a server error, no network - with
        gh's message, which names the HTTP status when there is one.
        Waiting out a failure would only delay that error, so
        -TimeoutSeconds bounds the wait only while the reads succeed.

        Each poll is one gh call with no time limit of its own, so a gh
        that stalls on the network stalls the wait with it.
    .PARAMETER RunId
        The run, by its database id. A run piped in from
        Get-GitHubWorkflowRun binds by its DatabaseId; a job, or any other
        object whose Url is not that run's, is refused.
    .PARAMETER TimeoutSeconds
        How many seconds to wait for each run to finish - each one piped
        in gets the whole of it - 1 to 86400.
        The default is 1800. The run is polled once more at the deadline,
        and a run still going then throws a TimeoutException naming its
        last status.
    .PARAMETER PollSeconds
        How many seconds to wait between polls, 1 to 3600. The default is
        5; the last pause is cut short at the deadline.
    .PARAMETER Repository
        The repository, as [HOST/]OWNER/REPO, a URL, or a repository
        object. A run piped in is acted on where it came from - its
        Repository, else its Url - and a -Repository that names another
        repository throws. Omit both to use the current directory's
        repository; a -Repository given as $null throws.
    .INPUTS
        System.Int64
        A run id, or a workflow run object such as Get-GitHubWorkflowRun
        returns, whose DatabaseId binds to -RunId. A Repository property,
        when the object has one, binds to -Repository.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        The finished run, as Get-GitHubWorkflowRun returns it - Status
        completed, Conclusion, Jobs, and the rest. A run that ended
        cancelled, skipped, or failed is completed too, with that
        Conclusion, so check the Conclusion. A run still going at the
        deadline throws a TimeoutException instead.
    .EXAMPLE
        $run = Wait-GitHubWorkflowRun -RunId $runId -TimeoutSeconds 900

        Waits up to 15 minutes for the run, whose id came from
        Start-GitHubWorkflow's DatabaseId - or, on a gh older than 2.87,
        from Wait-GitHubWorkflowRunStart. $run.Conclusion says how it
        finished.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Start-GitHubWorkflow
    .LINK
        Get-GitHubWorkflowRun
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$RunId,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 1800,

        [ValidateRange(1, 3600)]
        [int]$PollSeconds = 5,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            Resolve-GitHubRepositoryArgument -Value $Repository -Given $PSBoundParameters.ContainsKey('Repository') |
                Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $piped = if ($MyInvocation.ExpectingInput) { $_ } else { $null }
            $repositoryReference = Resolve-GitHubRunRepository -InputObject $piped -RunId $RunId `
                -Repository $Repository `
                -Advice 'Give the run it belongs to.'
            $arguments = @('run', 'view', $RunId, '--json', 'status')
            $activity = "Reading workflow run $RunId"
            $poll = New-GitHubPoll -TimeoutSeconds $TimeoutSeconds -PollSeconds $PollSeconds
            while ($true) {
                $result = Invoke-GitHubCommand -Activity $activity -Arguments $arguments `
                    -Repository $repositoryReference `
                    -Tolerant
                Assert-GitHubPollRead -Result $result -Action "read workflow run $RunId"
                $run = @(ConvertFrom-GitHubJson -Lines $result.Output) | Select-Object -First 1
                $status = $null
                if ($null -ne $run) {
                    $status = $run.PSObject.Properties['Status']?.Value
                }

                if ($status -eq 'completed') {
                    $readBack = @{ RunId = $RunId }
                    if ($repositoryReference) {
                        $readBack['Repository'] = $repositoryReference
                    }

                    return Get-GitHubWorkflowRun @readBack
                }

                if (Test-GitHubPollExpired -Poll $poll) {
                    $state = if ($status) { "was still $status" } else { 'had no status' }
                    $subject = "Workflow run $RunId $state after $TimeoutSeconds s."
                    $message = Get-GitHubTimeoutMessage -Subject $subject
                    throw [TimeoutException]::new($message)
                }

                Wait-GitHubPoll -Poll $poll | Out-Null
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
