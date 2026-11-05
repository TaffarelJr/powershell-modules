function Get-GitHubWorkflowRunLog {
    <#
    .SYNOPSIS
        Returns the log of a workflow run, or of one job in it, as text
        lines.
    .DESCRIPTION
        gh fetches the run's logs as one archive where it can and falls
        back to fetching each job's log separately where it cannot; a
        run with more than 25 such jobs fails on that fallback.

        Asked for neither a run nor a job, gh would ask which run, which
        it cannot do here, and fails saying so.
    .PARAMETER RunId
        The run, by its database id. Omit it when naming a -Job. A run
        piped in binds by its DatabaseId; a job, or any other object whose
        Url is not that run's, is refused - unless -Job is given.
    .PARAMETER Job
        One job's database id, to return only its log. A bare run id piped
        in with it counts as -RunId. Without -RunId, an object piped in
        with it only names the repository, by its Repository: a run, a
        job, or an object with no Url passes; a release or other object
        whose Url is no run's is refused.
    .PARAMETER Failed
        Returns only the failed steps' log lines.
    .PARAMETER Attempt
        Which attempt of the run to read. Omit it for the latest.
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
        System.String
        The log lines, one at a time.
    .EXAMPLE
        Get-GitHubWorkflowRunLog -RunId 123456789 -Failed `
            -Repository 'OWNER/REPO'

        Returns the log lines of the failed steps of run 123456789.
    .EXAMPLE
        Get-GitHubWorkflowRunLog -Job 987654321

        Returns the log of one job, in the current directory's
        repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Get-GitHubWorkflowRun
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$RunId,

        [ValidateRange(1, [long]::MaxValue)]
        [long]$Job,

        [switch]$Failed,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Attempt,

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
            $runGiven = $PSBoundParameters.ContainsKey('RunId')
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
            $bareId = $piped -is [string] -or $piped -is [ValueType]
            $jobOnly = $PSBoundParameters.ContainsKey('Job') -and -not $runGiven -and -not $bareId
            $repositoryReference = Resolve-GitHubRunRepository -InputObject $piped -RunId $RunId `
                -Repository $Repository `
                -Advice 'For its log, give its DatabaseId to -Job.' `
                -Item $(if ($jobOnly) { "Job $Job" } else { "Workflow run $RunId" }) `
                -NoRun:$jobOnly
            $arguments = @('run', 'view')
            if ($PSBoundParameters.ContainsKey('RunId') -and -not $jobOnly) {
                $arguments += $RunId
            }

            if ($PSBoundParameters.ContainsKey('Job')) {
                $arguments += @('--job', $Job)
            }

            $arguments += if ($Failed) { '--log-failed' } else { '--log' }
            if ($PSBoundParameters.ContainsKey('Attempt')) {
                $arguments += @('--attempt', $Attempt)
            }

            $activity = 'Reading the workflow run log'
            return Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
