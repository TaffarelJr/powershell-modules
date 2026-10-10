function Get-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Returns one workflow run with its jobs, or lists a repository's
        recent runs.
    .DESCRIPTION
        Without -List, one run is described, jobs and steps included.
        With -List, the repository's recent runs are returned newest
        first, narrowed by the filters.
    .PARAMETER Id
        The run to describe, by its database id.
    .PARAMETER Attempt
        Which attempt of the run to describe. Omit it for the latest.
    .PARAMETER List
        Lists runs instead of describing one.
    .PARAMETER Workflow
        Lists only this workflow's runs, by name, file name, or id.
    .PARAMETER Branch
        Lists only runs on this branch.
    .PARAMETER Commit
        Lists only runs of this commit SHA.
    .PARAMETER Trigger
        Lists only runs triggered by this event, such as push or
        workflow_dispatch.
    .PARAMETER Status
        Lists only runs in this status or with this conclusion, such as
        in_progress, completed, success, or failure.
    .PARAMETER User
        Lists only runs triggered by this user.
    .PARAMETER Created
        Lists only runs created in this date range, in GitHub's search
        syntax such as '>=2026-01-01'.
    .PARAMETER All
        Includes runs of disabled workflows.
    .PARAMETER Limit
        The most runs to list. gh's default is 20.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per run with DatabaseId, Number, Attempt, Name,
        DisplayTitle, WorkflowName, WorkflowDatabaseId, Event,
        HeadBranch, HeadSha, Status, Conclusion, Url, and the timestamps -
        plus Jobs without -List. A single object without -List; always an
        array with it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'View', ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [long]$Id,

        [Parameter(ParameterSetName = 'View')]
        [int]$Attempt,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [string]$Workflow,

        [Parameter(ParameterSetName = 'List')]
        [string]$Branch,

        [Parameter(ParameterSetName = 'List')]
        [string]$Commit,

        [Parameter(ParameterSetName = 'List')]
        [string]$Trigger,

        [Parameter(ParameterSetName = 'List')]
        [string]$Status,

        [Parameter(ParameterSetName = 'List')]
        [string]$User,

        [Parameter(ParameterSetName = 'List')]
        [string]$Created,

        [Parameter(ParameterSetName = 'List')]
        [switch]$All,

        [Parameter(ParameterSetName = 'List')]
        [int]$Limit,

        [string]$Repository
    )

    process {
        $fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName'

        if (-not $List) {
            $arguments = @('run', 'view', $Id, '--json', "$fields,jobs")
            if ($Attempt -gt 0) {
                $arguments += @('--attempt', $Attempt)
            }

            $out = Invoke-GitHubCommand -Activity "Reading workflow run $Id" -Arguments $arguments -Repository $Repository
            return ConvertFrom-GitHubJson -Lines $out
        }

        $arguments = @('run', 'list', '--json', $fields)
        if ($Workflow) {
            $arguments += @('--workflow', $Workflow)
        }

        if ($Branch) {
            $arguments += @('--branch', $Branch)
        }

        if ($Commit) {
            $arguments += @('--commit', $Commit)
        }

        if ($Trigger) {
            $arguments += @('--event', $Trigger)
        }

        if ($Status) {
            $arguments += @('--status', $Status)
        }

        if ($User) {
            $arguments += @('--user', $User)
        }

        if ($Created) {
            $arguments += @('--created', $Created)
        }

        if ($All) {
            $arguments += '--all'
        }

        if ($Limit -gt 0) {
            $arguments += @('--limit', $Limit)
        }

        $out = Invoke-GitHubCommand -Activity 'Listing workflow runs' -Arguments $arguments -Repository $Repository
        $runs = ConvertFrom-GitHubJson -Lines $out
        return , @($runs)
    }
}
