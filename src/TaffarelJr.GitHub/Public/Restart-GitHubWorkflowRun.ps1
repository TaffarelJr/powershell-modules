function Restart-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Reruns a workflow run - all of it, only its failed jobs, or one
        job and what depends on it.
    .DESCRIPTION
        A job is named by its database id, as Get-GitHubWorkflowRun
        reports under Jobs - not by the number in the job's browser URL,
        which GitHub does not accept here.
    .PARAMETER Id
        The run, by its database id.
    .PARAMETER Failed
        Reruns only the failed jobs, and the jobs that depend on them.
    .PARAMETER Job
        Reruns only this job, by its database id, and the jobs that
        depend on it.
    .PARAMETER DebugLogging
        Reruns with debug logging turned on.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [long]$Id,

        [switch]$Failed,

        [string]$Job,

        [switch]$DebugLogging,

        [string]$Repository
    )

    process {
        $arguments = @('run', 'rerun', $Id)
        if ($Failed) {
            $arguments += '--failed'
        }

        if ($Job) {
            $arguments += @('--job', $Job)
        }

        if ($DebugLogging) {
            $arguments += '--debug'
        }

        Invoke-GitHubCommand -Activity "Rerunning workflow run $Id" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
