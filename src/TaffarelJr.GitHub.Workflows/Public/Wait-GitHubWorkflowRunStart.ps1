function Wait-GitHubWorkflowRunStart {
    <#
    .SYNOPSIS
        Waits for a run dispatched by Start-GitHubWorkflow to appear, and
        returns its id.
    .DESCRIPTION
        A dispatch reports a URL but never the new run's id, and the run
        does not exist the instant the dispatch returns - so this polls
        gh for the workflow's recent runs until one not in -Before shows
        up. A handful of consecutive unreadable polls is tolerated as a
        transient blip; past that, it throws, since 'the run never
        started' would otherwise be indistinguishable from 'gh could not
        be reached'.
    .PARAMETER Workflow
        The workflow, by id, name, or file name such as 'ci.yml'.
    .PARAMETER Before
        The workflow's run ids immediately before dispatching, as
        Get-GitHubWorkflowRun -List returned them. Read this before
        calling Start-GitHubWorkflow, or the new run is in it too.
    .PARAMETER TimeoutSeconds
        How long to wait for the run to appear.
    .PARAMETER PollSeconds
        How many seconds to wait between polls.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    .OUTPUTS
        The new run's database id, or $null if none appeared within the
        timeout.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Workflow,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [long[]]$Before,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 300,

        [ValidateRange(1, 3600)]
        [int]$PollSeconds = 5,

        [string]$Repository
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $unreadable = 0
    while ((Get-Date) -lt $deadline) {
        $arguments = @('run', 'list', '--workflow', $Workflow, '--limit', '20', '--json', 'databaseId')
        $result = Invoke-GitHubCommand -Activity "Listing $Workflow runs" -Arguments $arguments -Repository $Repository -Tolerant

        if ($result.Ok) {
            $unreadable = 0
            $runs = ConvertFrom-GitHubJson -Lines $result.Output
            $ids = @($runs | Select-Object -ExpandProperty DatabaseId)
            $fresh = @($ids | Where-Object { $_ -notin $Before })
            if ($fresh) {
                return $fresh[0]
            }
        }
        else {
            $unreadable++
            if ($unreadable -ge $script:MaxUnreadablePolls) {
                throw "Could not list $Workflow runs ($unreadable attempts in a row failed)."
            }
        }

        Start-Sleep -Seconds $PollSeconds
    }

    return $null
}
