function Restart-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Reruns a workflow run - all of it or only its failed jobs - or one
        job and what depends on it.
    .DESCRIPTION
        A job is named by its database id alone, as Get-GitHubWorkflowRun
        reports under Jobs - not by the number in the job's browser URL,
        which GitHub does not accept here. gh finds the job's run itself,
        so a run id is not given with it, and -Failed has no meaning for
        one job.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER RunId
        The run, by its database id. A run piped in binds by its
        DatabaseId; a job, or any other object whose Url is not that run's,
        is refused. Give it or -Job, not both.
    .PARAMETER Failed
        Reruns only the run's failed jobs, and the jobs that depend on
        them.
    .PARAMETER Job
        Reruns only this job, by its database id, and the jobs that
        depend on it. An object piped in with it only names the
        repository, by its Repository: a run, a job, or an object with no
        Url passes; a release or other object whose Url is no run's is
        refused.
    .PARAMETER DebugLogging
        Reruns with debug logging turned on.
    .PARAMETER Repository
        The repository, as [HOST/]OWNER/REPO, a URL, or a repository
        object. A run piped in is acted on where it came from - its
        Repository, else its Url - and a -Repository that names another
        repository throws. Omit both to use the current directory's
        repository; a -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Int64
        A run id, or a workflow run object such as Get-GitHubWorkflowRun
        returns, whose DatabaseId binds to -RunId. A Repository property,
        when the object has one, binds to -Repository.
    .OUTPUTS
        None
    .EXAMPLE
        Restart-GitHubWorkflowRun -RunId 123456789 -Failed `
            -Repository 'OWNER/REPO'

        Reruns the failed jobs of run 123456789, and the jobs that depend
        on them.
    .EXAMPLE
        Restart-GitHubWorkflowRun -Job 987654321 -DebugLogging

        Reruns one job with debug logging, in the current directory's
        repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Stop-GitHubWorkflowRun
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$RunId,

        [switch]$Failed,

        [ValidateRange(1, [long]::MaxValue)]
        [long]$Job,

        [switch]$DebugLogging,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            Resolve-GitHubRepositoryArgument -Value $Repository -Given $PSBoundParameters.ContainsKey('Repository') |
                Out-Null
            $reasons = [ordered]@{
                RunId  = 'gh finds the job''s run itself, and would quietly ignore the one given'
                Failed = 'one job has no failed jobs to pick out, so gh would quietly ignore it'
            }
            foreach ($other in $reasons.PSBase.Keys) {
                if ($PSBoundParameters.ContainsKey('Job') -and $PSBoundParameters.ContainsKey($other)) {
                    throw "-$other and -Job cannot be used together: $($reasons[$other]). Give only one."
                }
            }
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
            $jobOnly = $PSBoundParameters.ContainsKey('Job')
            if ($jobOnly -and ($piped -is [string] -or $piped -is [ValueType])) {
                throw "-RunId and -Job cannot be used together: $($reasons['RunId']). Give only one."
            }

            if (-not $jobOnly -and $RunId -lt 1 -and $null -eq $piped) {
                throw 'Give -RunId, or -Job for one job.'
            }

            if ($jobOnly) {
                $arguments = @('run', 'rerun', '--job', $Job)
                $activity = "Rerunning job $Job"
                $item = "Job $Job"
                $action = 'Rerun job'
            }
            else {
                $arguments = @('run', 'rerun', $RunId)
                $action = 'Rerun workflow run'
                if ($Failed) {
                    $arguments += '--failed'
                    $action = 'Rerun failed jobs'
                }

                $activity = "Rerunning workflow run $RunId"
                $item = "Workflow run $RunId"
            }

            $repositoryReference = Resolve-GitHubRunRepository -InputObject $piped -RunId $RunId `
                -Repository $Repository `
                -Advice 'To rerun the job, give its DatabaseId to -Job.' `
                -Item $item `
                -NoRun:$jobOnly
            if ($DebugLogging) {
                $arguments += '--debug'
            }

            $target = Format-GitHubItemTarget -Repository $repositoryReference -Item $item.ToLowerInvariant()
            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
