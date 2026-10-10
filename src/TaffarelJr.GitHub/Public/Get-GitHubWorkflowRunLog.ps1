function Get-GitHubWorkflowRunLog {
    <#
    .SYNOPSIS
        Returns the log of a workflow run, or of one job in it, as text
        lines.
    .DESCRIPTION
        gh fetches the run's logs as one archive where it can and falls
        back to fetching each job's log separately where it cannot; a
        run with more than 25 such jobs fails on that fallback.
    .PARAMETER Id
        The run, by its database id. Omit it when naming a -Job.
    .PARAMETER Job
        One job's database id, to return only its log.
    .PARAMETER Failed
        Returns only the failed steps' log lines.
    .PARAMETER Attempt
        Which attempt of the run to read. Omit it for the latest.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        The log lines, always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Id,

        [string]$Job,

        [switch]$Failed,

        [int]$Attempt,

        [string]$Repository
    )

    $arguments = @('run', 'view')
    if ($Id) {
        $arguments += $Id
    }

    if ($Job) {
        $arguments += @('--job', $Job)
    }

    $arguments += if ($Failed) { '--log-failed' } else { '--log' }
    if ($Attempt -gt 0) {
        $arguments += @('--attempt', $Attempt)
    }

    return Invoke-GitHubCommand -Activity 'Reading the workflow run log' -Arguments $arguments -Repository $Repository
}
