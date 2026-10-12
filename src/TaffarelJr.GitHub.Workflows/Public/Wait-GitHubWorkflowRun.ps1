function Wait-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Waits for a workflow run to finish, then returns it.
    .DESCRIPTION
        Polls gh directly for the run's status rather than delegating to
        gh run watch, which has no timeout of its own and does not work
        with a fine-grained personal access token - that token type
        cannot carry the checks:read permission gh run watch needs. A
        handful of consecutive unreadable polls is tolerated as a
        transient blip; past that, it throws, since a status read once
        early would otherwise stand in for the run's real state at the
        deadline.
    .PARAMETER Id
        The run, by its database id.
    .PARAMETER TimeoutSeconds
        How long to wait for the run to finish.
    .PARAMETER PollSeconds
        How many seconds to wait between polls.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    .OUTPUTS
        The run, as Get-GitHubWorkflowRun returns it - Status,
        Conclusion, Jobs, and the rest. Still in_progress if the
        deadline passed before it finished.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [long]$Id,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 1800,

        [ValidateRange(1, 3600)]
        [int]$PollSeconds = 5,

        [string]$Repository
    )

    process {
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $unreadable = 0
        while ((Get-Date) -lt $deadline) {
            $result = Invoke-GitHubCommand -Activity "Reading workflow run $Id" -Arguments @('run', 'view', $Id, '--json', 'status') -Repository $Repository -Tolerant

            if ($result.Ok) {
                $unreadable = 0
                $status = (ConvertFrom-GitHubJson -Lines $result.Output).Status
                if ($status -eq 'completed') {
                    break
                }
            }
            else {
                $unreadable++
                if ($unreadable -ge $script:MaxUnreadablePolls) {
                    throw "Could not read workflow run $Id ($unreadable attempts in a row failed)."
                }
            }

            Start-Sleep -Seconds $PollSeconds
        }

        return Get-GitHubWorkflowRun -Id $Id -Repository $Repository
    }
}
