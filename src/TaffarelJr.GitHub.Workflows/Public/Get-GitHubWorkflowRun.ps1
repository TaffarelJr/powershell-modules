function Get-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Returns one workflow run with its jobs, or lists a repository's
        recent runs.
    .DESCRIPTION
        Without -List, one run is described, jobs and steps included.
        With -List, the repository's recent runs are returned newest
        first, narrowed by the filters; workflows piped in from
        Get-GitHubWorkflow each list their own runs.

        Needs gh 2.50 or later, the first to report a run's attempt.
    .PARAMETER RunId
        The run to describe, by its database id. A run piped in binds by
        its DatabaseId; a job, or any other object whose Url is not that
        run's, is refused.
    .PARAMETER Attempt
        Which attempt of the run to describe. Omit it for the latest.
    .PARAMETER List
        Lists runs instead of describing one.
    .PARAMETER Workflow
        Lists only this workflow's runs, by name, file name, or id, or a
        workflow object, read by its Id - piped in too.
    .PARAMETER Branch
        Lists only runs on this branch. A blank value is refused.
    .PARAMETER Commit
        Lists only runs of this commit SHA. A blank value is refused.
    .PARAMETER Trigger
        Lists only runs triggered by this event (gh's --event), such as
        push or workflow_dispatch. A blank value is refused.
    .PARAMETER Status
        Lists only runs in this status or with this conclusion, such as
        in_progress, completed, success, or failure. A blank value is
        refused.
    .PARAMETER User
        Lists only runs triggered by this user (gh's --user). A blank value
        is refused.
    .PARAMETER Created
        Lists only runs created in this date range, in GitHub's search
        syntax such as '>=2026-01-01'. A blank value is refused.
    .PARAMETER All
        With -Workflow given by name, finds that workflow even when it is
        disabled; gh looks a name up among enabled workflows only, unless
        told otherwise with its --all. Needs gh 2.52 or later.
    .PARAMETER Limit
        The most runs to list, at least 1. gh's default is 20.
    .PARAMETER Repository
        The repository to read, as [HOST/]OWNER/REPO, a URL, or a
        repository object. A run or workflow piped in is read where it
        came from - its Repository, else its Url - and a -Repository that
        names another repository throws. Omit both to use the current
        directory's repository; a -Repository given as $null throws.
    .INPUTS
        System.Int64
        Without -List, a run id, or a workflow run object such as this
        function returns, whose DatabaseId binds to -RunId.
        System.Object
        With -List, a workflow, by id, name, or file name, or a workflow
        object such as Get-GitHubWorkflow returns. Binds to -Workflow.
        A Repository property, when the object has one, binds to
        -Repository.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per run with DatabaseId, Number, Attempt, Name,
        DisplayTitle, WorkflowName, WorkflowDatabaseId, Event,
        HeadBranch, HeadSha, Status, Conclusion, Url, and the timestamps -
        plus Jobs without -List, and Repository, the repository it was
        read from (-Repository, else the one in its Url, else $null),
        written OWNER/REPO, or HOST/OWNER/REPO off github.com, however it
        was named. A single object without -List; one per run with it.
    .EXAMPLE
        Get-GitHubWorkflowRun -RunId 123456789 -Repository 'OWNER/REPO'

        Returns run 123456789 with its jobs and steps.
    .EXAMPLE
        Get-GitHubWorkflowRun -List -Workflow 'ci.yml' -Branch main `
            -Status failure -Limit 5 -Repository 'OWNER/REPO'

        Lists the five latest failed runs of ci.yml on main.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Get-GitHubWorkflow
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'View',
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('DatabaseId')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$RunId,

        [Parameter(ParameterSetName = 'View')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Attempt,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List', ValueFromPipeline)]
        [object]$Workflow,

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
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

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
            $filterNames = @('Branch', 'Commit', 'Trigger', 'Status', 'User', 'Created')
            Assert-GitHubFilterNotBlank -BoundParameters $PSBoundParameters -Name $filterNames
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,' +
            'startedAt,status,updatedAt,url,workflowDatabaseId,workflowName'

            if (-not $List) {
                $piped = if ($MyInvocation.ExpectingInput) { $_ } else { $null }
                $repositoryReference = Resolve-GitHubRunRepository -InputObject $piped -RunId $RunId `
                    -Repository $Repository `
                    -Advice 'Give the run it belongs to; its Jobs describe each job.'
                $arguments = @('run', 'view', $RunId, '--json', "$fields,jobs")
                if ($PSBoundParameters.ContainsKey('Attempt')) {
                    $arguments += @('--attempt', $Attempt)
                }

                $activity = "Reading workflow run $RunId"
            }
            else {
                $arguments = @('run', 'list', '--json', $fields)
                $item = 'The listing'
                $workflowUrl = ''
                if ($PSBoundParameters.ContainsKey('Workflow')) {
                    $reference = ConvertTo-GitHubWorkflowReference -Workflow $Workflow
                    $arguments += @('--workflow', $reference)
                    $item = "Workflow $reference"
                    if ($Workflow -isnot [string] -and $Workflow -isnot [ValueType]) {
                        $workflowUrl = "$($Workflow.PSObject.Properties['Url']?.Value)"
                    }
                }

                $repositoryReference = Resolve-GitHubOriginRepository -Repository $Repository -InputObject $Workflow `
                    -Url $workflowUrl `
                    -Item $item
                $filters = [ordered]@{
                    '--branch'  = $Branch
                    '--commit'  = $Commit
                    '--event'   = $Trigger
                    '--status'  = $Status
                    '--user'    = $User
                    '--created' = $Created
                }
                foreach ($flag in $filters.PSBase.Keys) {
                    if ($filters[$flag]) {
                        $arguments += "$flag=$($filters[$flag])"
                    }
                }

                if ($All) {
                    $arguments += '--all'
                }

                if ($PSBoundParameters.ContainsKey('Limit')) {
                    $arguments += @('--limit', $Limit)
                }

                $activity = 'Listing workflow runs'
            }

            $out = Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference
            $runs = ConvertFrom-GitHubJson -Lines $out
            foreach ($run in $runs) {
                $origin = $repositoryReference
                if (-not $origin) {
                    $url = "$($run.PSObject.Properties['Url']?.Value)"
                    $origin = Resolve-GitHubOriginRepository -Url $url -Item 'The run'
                }

                if ($origin) {
                    $origin = Format-GitHubRepositoryName -Repository $origin
                }

                $run | Add-Member -NotePropertyName 'Repository' -NotePropertyValue $origin
                $run
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
